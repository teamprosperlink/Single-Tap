import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../home/main_navigation_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../providers/other providers/app_providers.dart';
import '../../res/config/app_colors.dart';
import '../../widgets/common widgets/app_background.dart';
import '../../services/auth_service.dart';
import '../performance_debug_screen.dart';
import '../login/choose_account_type_screen.dart';
import '../login/change_password_screen.dart';
import '../location/location_settings_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'safety_tips_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common widgets/coming_soon_widget.dart';
import 'personalization_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);
  bool _discoveryModeEnabled = true;

  // Notification preferences
  bool _messageNotifications = true;
  bool _matchNotifications = true;
  bool _connectionRequestNotifications = true;
  bool _promotionalNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final userId = _currentUserId;
    if (userId != null) {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _discoveryModeEnabled = data['discoveryModeEnabled'] ?? true;
          _messageNotifications = data['messageNotifications'] ?? true;
          _matchNotifications = data['matchNotifications'] ?? true;
          _connectionRequestNotifications =
              data['connectionRequestNotifications'] ?? true;
          _promotionalNotifications = data['promotionalNotifications'] ?? false;
        });
      }
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final userId = _currentUserId;
    if (userId != null) {
      try {
        await _firestore.collection('users').doc(userId).update({key: value});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update setting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // Keep for theme state changes
    final authService = AuthService(); // ignore: unused_local_variable

    // Always use dark theme style since we're using AppBackground
    const bool isDark = true;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            // Open drawer after returning
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MainNavigationScreen.scaffoldKey.currentState
                  ?.openEndDrawer();
            });
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
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
        ),
      ),
      body: AppBackground(
        showParticles: false,
        overlayOpacity: 0.7,
        child: ListView(
          padding: const EdgeInsets.only(
            top: kToolbarHeight + 40,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          children: [
            // Account Section
            _buildSectionHeader(
              icon: CupertinoIcons.person_circle_fill,
              title: 'Account',
              color: AppColors.iosBlue,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildIndividualSwitchItem(
              icon: Icons.visibility_outlined,
              title: 'Discoverable on Live Connect',
              subtitle: 'Allow others to find you in nearby people',
              value: _discoveryModeEnabled,
              onChanged: (value) {
                setState(() => _discoveryModeEnabled = value);
                _updatePreference('discoveryModeEnabled', value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? 'You are now discoverable on Live Connect'
                          : 'You are now hidden from Live Connect searches',
                    ),
                    backgroundColor: value ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.security_outlined,
              title: 'Privacy',
              subtitle: 'Manage your privacy settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalizationScreen(),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Password and authentication',
              onTap: () {
                _showSecurityOptions(context);
              },
            ),
            _buildIndividualItem(
              icon: Icons.block_outlined,
              title: 'Blocked Users',
              subtitle: 'Manage blocked accounts',
              onTap: () {
                _showBlockedUsers(context);
              },
            ),

            const SizedBox(height: 10),

            // Notifications Section
            _buildSectionHeader(
              icon: CupertinoIcons.bell_fill,
              title: 'Notifications',
              color: AppColors.iosOrange,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildIndividualSwitchItem(
              icon: Icons.message_outlined,
              title: 'Message Notifications',
              subtitle: 'New messages from matches',
              value: _messageNotifications,
              onChanged: (value) {
                setState(() => _messageNotifications = value);
                _updatePreference('messageNotifications', value);
              },
            ),
            _buildIndividualSwitchItem(
              icon: Icons.favorite_outline,
              title: 'Match Notifications',
              subtitle: 'Someone matched with you',
              value: _matchNotifications,
              onChanged: (value) {
                setState(() => _matchNotifications = value);
                _updatePreference('matchNotifications', value);
              },
            ),
            _buildIndividualSwitchItem(
              icon: Icons.people_outline,
              title: 'Connection Requests',
              subtitle: 'New connection requests',
              value: _connectionRequestNotifications,
              onChanged: (value) {
                setState(() => _connectionRequestNotifications = value);
                _updatePreference('connectionRequestNotifications', value);
              },
            ),
            _buildIndividualSwitchItem(
              icon: Icons.campaign_outlined,
              title: 'Promotional',
              subtitle: 'Updates and offers',
              value: _promotionalNotifications,
              onChanged: (value) {
                setState(() => _promotionalNotifications = value);
                _updatePreference('promotionalNotifications', value);
              },
            ),

            const SizedBox(height: 10),

            // App Settings Section
            _buildSectionHeader(
              icon: CupertinoIcons.gear_solid,
              title: 'App Settings',
              color: AppColors.iosGreen,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildIndividualItem(
              icon: Icons.location_on_outlined,
              title: 'Location',
              subtitle: 'Manage location settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationSettingsScreen(),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.storage_outlined,
              title: 'Storage & Data',
              subtitle: 'Network usage and storage',
              onTap: () {
                _showStorageOptions(context);
              },
            ),
            _buildIndividualItem(
              icon: Icons.cleaning_services_outlined,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
            _buildIndividualItem(
              icon: Icons.speed_outlined,
              title: 'Performance Debug',
              subtitle: 'Monitor app performance',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PerformanceDebugScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Coming Soon Section
            _buildSectionHeader(
              icon: CupertinoIcons.sparkles,
              title: 'Coming Soon',
              color: AppColors.iosPink,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildComingSoonItem(
              icon: Icons.workspace_premium,
              title: 'Premium',
              subtitle: 'Unlock exclusive features',
              colors: [Colors.amber, Colors.orange],
              onTap: () {
                showComingSoonDialog(
                  context,
                  featureName: 'Premium Subscription',
                  description:
                      'Unlock unlimited matches, priority visibility, advanced filters, and ad-free experience.',
                  icon: Icons.workspace_premium,
                  color: Colors.amber,
                );
              },
            ),
            _buildComingSoonItem(
              icon: Icons.event,
              title: 'Events',
              subtitle: 'Discover local events',
              colors: [Colors.purple, Colors.pink],
              onTap: () {
                showComingSoonDialog(
                  context,
                  featureName: 'Events',
                  description:
                      'Create and discover local events, meetups, and gatherings in your area.',
                  icon: Icons.event,
                  color: Colors.purple,
                );
              },
            ),
            _buildComingSoonItem(
              icon: Icons.groups,
              title: 'Groups',
              subtitle: 'Join interest-based groups',
              colors: [Colors.blue, Colors.cyan],
              onTap: () {
                showComingSoonDialog(
                  context,
                  featureName: 'Groups',
                  description:
                      'Create and join interest-based groups to connect with like-minded people.',
                  icon: Icons.groups,
                  color: Colors.blue,
                );
              },
            ),
            _buildComingSoonItem(
              icon: Icons.auto_stories,
              title: 'Stories',
              subtitle: 'Share your moments',
              colors: [Colors.green, Colors.teal],
              onTap: () {
                showComingSoonDialog(
                  context,
                  featureName: 'Stories',
                  description:
                      'Share photos and videos that disappear after 24 hours with your connections.',
                  icon: Icons.auto_stories,
                  color: Colors.green,
                );
              },
            ),

            const SizedBox(height: 10),

            // Support Section
            _buildSectionHeader(
              icon: CupertinoIcons.question_circle_fill,
              title: 'Support',
              color: AppColors.iosTeal,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildIndividualItem(
              icon: Icons.shield_outlined,
              title: 'Safety Tips',
              subtitle: 'Stay safe while connecting',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SafetyTipsScreen(),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            _buildIndividualItem(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _buildIndividualItem(
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              subtitle: 'Help us improve the app',
              onTap: () {
                _showFeedbackDialog(context);
              },
            ),
            _buildIndividualItem(
              icon: Icons.bug_report_outlined,
              title: 'Report a Problem',
              subtitle: 'Let us know if something isn\'t working',
              onTap: () {
                _showReportProblemDialog(context);
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              CupertinoIcons.chevron_forward,
              color: Colors.white.withValues(alpha: 0.5),
            ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildIndividualSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          width: 1,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildComingSoonItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        trailing: _buildComingSoonBadge(),
        onTap: onTap,
      ),
    );
  }

  // Blocked Users
  void _showBlockedUsers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: const Text(
              'Blocked Users',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: Container(
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
            ),
          ),
          body: AppBackground(
            showParticles: false,
            overlayOpacity: 0.7,
            child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('blocked')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              // Deduplicate by doc.id
              final seenIds = <String>{};
              final blockedUsers = snapshot.data!.docs
                  .where((doc) => seenIds.add(doc.id))
                  .toList();

              if (blockedUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No Blocked Users',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 18, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: kToolbarHeight + 44, left: 16, right: 16, bottom: 16),
                itemCount: blockedUsers.length,
                itemBuilder: (context, index) {
                  final blockedUser = blockedUsers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            blockedUser['name']?[0] ?? 'U',
                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            blockedUser['name'] ?? 'Unknown',
                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _firestore
                                .collection('users')
                                .doc(_currentUserId)
                                .collection('blocked')
                                .doc(blockedUser.id)
                                .delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User unblocked'), backgroundColor: Colors.green),
                              );
                            }
                          },
                          child: const Text('Unblock', style: TextStyle(fontFamily: 'Poppins', color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          ),
        ),
      ),
    );
  }

  // Security Options
  void _showSecurityOptions(BuildContext context) {
    final authService = AuthService();
    final hasPassword = authService.hasPasswordProvider();
    final signInMethod = authService.getPrimarySignInMethod();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Security',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(
                Icons.lock_outline,
                color: hasPassword ? Colors.white : Colors.grey,
              ),
              title: Text(
                'Change Password',
                style: TextStyle(fontFamily: 'Poppins', color: hasPassword ? Colors.white : Colors.grey),
              ),
              subtitle: Text(
                hasPassword
                    ? 'Update your password'
                    : signInMethod == 'google.com'
                    ? 'You signed in with Google'
                    : 'Not available for your account type',
                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: hasPassword ? Colors.white : Colors.grey,
              ),
              enabled: hasPassword,
              onTap: hasPassword
                  ? () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      );
                    }
                  : () {
                      // Show explanation for Google users
                      if (signInMethod == 'google.com') {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
                            title: const Text(
                              'Google Account',
                              style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              'You signed in with Google. To change your password, please:\n\n'
                              '1. Go to myaccount.google.com\n'
                              '2. Navigate to Security\n'
                              '3. Select "Password"\n'
                              '4. Follow Google\'s password change process\n\n'
                              'Your Google password will automatically work with this app.',
                              style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),
            ListTile(
              leading: const Icon(Icons.devices_outlined, color: Colors.blue),
              title: const Text(
                'Manage Devices',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.blue),
              ),
              subtitle: const Text(
                'View and logout from devices',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.blue),
              onTap: () {
                Navigator.pop(context);
                _showManageDevices(context, authService);
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text(
                'Logout',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.orange),
              ),
              subtitle: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.orange),
              onTap: () {
                // IMPORTANT: Close parent dialog first (Security dialog)
                // This allows the logout dialog to show properly
                Navigator.pop(context);
                // Schedule logout dialog to show after parent dialog closes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showLogoutDialog(context, authService);
                });
              },
            ),
            Divider(color: Colors.white.withValues(alpha: 0.2)),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.red),
              ),
              subtitle: const Text(
                'Permanently delete',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white70),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Force logout another device by clearing its active device token
  Future<void> _forceLogoutDevice(BuildContext context, String userId) async {
    try {
      // Delete the activeDeviceToken from Firestore
      // This will trigger the Firestore listener on the other device
      // and it will automatically logout
      await _firestore.collection('users').doc(userId).update({
        'activeDeviceToken': FieldValue.delete(),
        'deviceInfo': FieldValue.delete(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Device has been logged out remotely')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manage Devices - View all logged-in devices and logout from other devices
  void _showManageDevices(BuildContext context, AuthService authService) {
    final userId = _currentUserId;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Manage Devices',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: FutureBuilder<String?>(
          future: authService.getLocalDeviceToken(),
          builder: (context, localTokenSnapshot) {
            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(userId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                if (userData == null) {
                  return const Text('Unable to load device information', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70));
                }

                final deviceInfo =
                    userData['deviceInfo'] as Map<String, dynamic>? ?? {};
                final activeDeviceToken =
                    userData['activeDeviceToken'] as String?;
                final localToken = localTokenSnapshot.data;

                // Determine if this is the current device
                final isCurrentDevice =
                    activeDeviceToken != null &&
                    localToken != null &&
                    activeDeviceToken == localToken;

                final deviceName =
                    deviceInfo['deviceName'] as String? ?? 'This Device';
                final deviceModel =
                    deviceInfo['deviceModel'] as String? ?? 'Unknown Model';
                final platform = deviceInfo['platform'] as String? ?? 'Unknown';
                final osVersion =
                    deviceInfo['osVersion'] as String? ?? 'Unknown';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Device',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                platform == 'android'
                                    ? Icons.android
                                    : Icons.phone_iphone,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceName,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '$deviceModel • $platform $osVersion',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrentDevice)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Current',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Last active: Just now',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!isCurrentDevice)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _forceLogoutDevice(context, userId);
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout This Device'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    const Text(
                      'Security Info',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber[700],
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Only one device can be logged in at a time. Logging in on another device will automatically logout this device.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.amber[300],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Logout confirmation dialog
  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Logout',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Call signOut - this triggers StreamBuilder to detect logout
              await authService.signOut();

              // StreamBuilder should rebuild and handle navigation
              // Give it time to detect the auth state change
              await Future.delayed(const Duration(milliseconds: 1000));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Logout', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  // Delete Account
  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Delete Account',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              'Type "DELETE" to confirm:',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmController,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                hintText: 'DELETE',
                hintStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (confirmController.text == 'DELETE') {
                try {
                  // Delete user data from Firestore
                  final userId = _currentUserId;
                  if (userId != null) {
                    await _firestore.collection('users').doc(userId).delete();
                  }

                  // Delete authentication account
                  await FirebaseAuth.instance.currentUser?.delete();

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const ChooseAccountTypeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  // Storage & Cache Management
  Future<void> _showStorageOptions(BuildContext context) async {
    // Show loading dialog while calculating
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Calculating storage...',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );

    try {
      // Calculate actual storage
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getTemporaryDirectory();

      final appSize = await _getDirectorySize(appDir);
      final cacheSize = await _getDirectorySize(cacheDir);
      final totalSize = appSize + cacheSize;

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
            title: const Text(
              'Storage & Data',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined, color: Colors.white),
                  title: const Text('App Data', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                  subtitle: Text(
                    '${(appSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.cached_outlined, color: Colors.white),
                  title: const Text('Cache', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                  subtitle: Text(
                    '${(cacheSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.2)),
                ListTile(
                  leading: const Icon(Icons.storage_outlined, color: Colors.white),
                  title: const Text('Total Storage', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                  subtitle: Text(
                    '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating storage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearCacheDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Clear Cache',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will clear temporary files and cached images. Your account data will not be affected.',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
              );

              try {
                double freedSpace = 0;

                // Clear cached network images
                await CachedNetworkImage.evictFromCache('');
                final imageCache = PaintingBinding.instance.imageCache;
                imageCache.clear();
                imageCache.clearLiveImages();

                // Clear app cache directory
                final cacheDir = await getTemporaryDirectory();
                if (cacheDir.existsSync()) {
                  final cacheSize = await _getDirectorySize(cacheDir);
                  freedSpace = cacheSize / (1024 * 1024); // Convert to MB

                  // Delete cache files
                  await _deleteDirectory(cacheDir);
                }

                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cache cleared successfully! Freed ${freedSpace.toStringAsFixed(2)} MB',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing cache: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear', style: TextStyle(fontFamily: 'Poppins', color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<int> _getDirectorySize(Directory directory) async {
    int size = 0;
    try {
      if (directory.existsSync()) {
        directory.listSync(recursive: true, followLinks: false).forEach((
          entity,
        ) {
          if (entity is File) {
            size += entity.lengthSync();
          }
        });
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return size;
  }

  Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
        // Recreate the directory
        await directory.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting directory: $e');
    }
  }

  // Feedback & Report
  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: const Text(
          'Send Feedback',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We\'d love to hear your thoughts!',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedbackController,
              maxLines: 5,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                hintText: 'Share your feedback here...',
                hintStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              if (feedbackController.text.isNotEmpty) {
                try {
                  await _firestore.collection('feedback').add({
                    'userId': _currentUserId,
                    'userEmail': FirebaseAuth.instance.currentUser?.email,
                    'feedback': feedbackController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                    'type': 'feedback',
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you for your feedback!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send feedback: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send', style: TextStyle(fontFamily: 'Poppins', color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showReportProblemDialog(BuildContext context) {
    final TextEditingController problemController = TextEditingController();
    String selectedCategory = 'Bug';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
            title: const Text(
              'Report a Problem',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    labelText: 'Problem Type',
                    labelStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                  items: ['Bug', 'Crash', 'Feature Request', 'Other']
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category, style: const TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: problemController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    hintText: 'Describe the problem...',
                    hintStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
              ),
              TextButton(
                onPressed: () async {
                  if (problemController.text.isNotEmpty) {
                    try {
                      await _firestore.collection('feedback').add({
                        'userId': _currentUserId,
                        'userEmail': FirebaseAuth.instance.currentUser?.email,
                        'problem': problemController.text,
                        'category': selectedCategory,
                        'timestamp': FieldValue.serverTimestamp(),
                        'type': 'problem',
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Report submitted. We\'ll look into it!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit report: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Submit', style: TextStyle(fontFamily: 'Poppins', color: Colors.orange)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Coming Soon badge widget
  Widget _buildComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withValues(alpha: 0.8),
            Colors.blue.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'SOON',
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // About dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1)),
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withValues(alpha: 0.6),
                    Colors.blue.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Single Tap',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Single Tap is an AI-powered matching app that connects people for various purposes - marketplace, dating, friendship, jobs, and more.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.copyright,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  '2024 Single Tap Inc. All rights reserved.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontFamily: 'Poppins', color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
