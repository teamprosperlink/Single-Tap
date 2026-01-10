import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../providers/other providers/app_providers.dart';
import '../../res/config/app_colors.dart';
import '../../services/auth_service.dart';
import '../performance_debug_screen.dart';
import '../login/choose_account_type_screen.dart';
import '../login/change_password_screen.dart';
import '../location/location_settings_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'safety_tips_screen.dart';
import 'help_center_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/coming_soon_widget.dart';

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
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDarkMode;
    final isGlass = themeState.isGlassmorphism;
    final authService = AuthService(); // ignore: unused_local_variable

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              backgroundColor: isGlass
                  ? Colors.white.withValues(alpha: 0.7)
                  : (isDark
                        ? Colors.black.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.9)),
              elevation: 0,
              centerTitle: false,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // iOS 16 Glassmorphism gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isGlass
                    ? [
                        const Color(0xFFE3F2FD).withValues(alpha: 0.8),
                        const Color(0xFFF3E5F5).withValues(alpha: 0.6),
                        const Color(0xFFE8F5E9).withValues(alpha: 0.4),
                        const Color(0xFFFFF3E0).withValues(alpha: 0.3),
                      ]
                    : isDark
                    ? [Colors.black, const Color(0xFF1C1C1E)]
                    : [const Color(0xFFF5F5F7), Colors.white],
              ),
            ),
          ),

          // Floating glass circles for depth
          if (isGlass) ...[
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.iosPurple.withValues(alpha: 0.3),
                      AppColors.iosPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.iosBlue.withValues(alpha: 0.2),
                      AppColors.iosBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],

          ListView(
            padding: const EdgeInsets.only(
              top: kToolbarHeight + 60,
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
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_outlined),
                    title: const Text('Discoverable on Live Connect'),
                    subtitle: const Text(
                      'Allow others to find you in nearby people',
                    ),
                    value: _discoveryModeEnabled,
                    onChanged: (value) {
                      setState(() => _discoveryModeEnabled = value);
                      _updatePreference('discoveryModeEnabled', value);

                      // Show feedback
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Privacy'),
                    subtitle: const Text('Manage your privacy settings'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Navigate to privacy settings
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Security'),
                    subtitle: const Text('Password and authentication'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showSecurityOptions(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: const Text('Blocked Users'),
                    subtitle: const Text('Manage blocked accounts'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showBlockedUsers(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Notifications Section
              _buildSectionHeader(
                icon: CupertinoIcons.bell_fill,
                title: 'Notifications',
                color: AppColors.iosOrange,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.message_outlined),
                    title: const Text('Message Notifications'),
                    subtitle: const Text('New messages from matches'),
                    value: _messageNotifications,
                    onChanged: (value) {
                      setState(() => _messageNotifications = value);
                      _updatePreference('messageNotifications', value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.favorite_outline),
                    title: const Text('Match Notifications'),
                    subtitle: const Text('Someone matched with you'),
                    value: _matchNotifications,
                    onChanged: (value) {
                      setState(() => _matchNotifications = value);
                      _updatePreference('matchNotifications', value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.people_outline),
                    title: const Text('Connection Requests'),
                    subtitle: const Text('New connection requests'),
                    value: _connectionRequestNotifications,
                    onChanged: (value) {
                      setState(() => _connectionRequestNotifications = value);
                      _updatePreference(
                        'connectionRequestNotifications',
                        value,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.campaign_outlined),
                    title: const Text('Promotional'),
                    subtitle: const Text('Updates and offers'),
                    value: _promotionalNotifications,
                    onChanged: (value) {
                      setState(() => _promotionalNotifications = value);
                      _updatePreference('promotionalNotifications', value);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // App Settings Section
              _buildSectionHeader(
                icon: CupertinoIcons.gear_solid,
                title: 'App Settings',
                color: AppColors.iosGreen,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('Language'),
                    subtitle: const Text('English'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      // TODO: Language selection
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Location'),
                    subtitle: const Text('Manage location settings'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LocationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Storage & Data'),
                    subtitle: const Text('Network usage and storage'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showStorageOptions(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Clear Cache'),
                    subtitle: const Text('Free up storage space'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showClearCacheDialog(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.speed_outlined),
                    title: const Text('Performance Debug'),
                    subtitle: const Text('Monitor app performance'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PerformanceDebugScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Coming Soon Section
              _buildSectionHeader(
                icon: CupertinoIcons.sparkles,
                title: 'Coming Soon',
                color: AppColors.iosPink,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.withValues(alpha: 0.3), Colors.orange.withValues(alpha: 0.3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                    ),
                    title: const Text('Premium'),
                    subtitle: const Text('Unlock exclusive features'),
                    trailing: _buildComingSoonBadge(),
                    onTap: () {
                      showComingSoonDialog(
                        context,
                        featureName: 'Premium Subscription',
                        description: 'Unlock unlimited matches, priority visibility, advanced filters, and ad-free experience.',
                        icon: Icons.workspace_premium,
                        color: Colors.amber,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withValues(alpha: 0.3), Colors.pink.withValues(alpha: 0.3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event, color: Colors.purple, size: 20),
                    ),
                    title: const Text('Events'),
                    subtitle: const Text('Discover local events'),
                    trailing: _buildComingSoonBadge(),
                    onTap: () {
                      showComingSoonDialog(
                        context,
                        featureName: 'Events',
                        description: 'Create and discover local events, meetups, and gatherings in your area.',
                        icon: Icons.event,
                        color: Colors.purple,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.withValues(alpha: 0.3), Colors.cyan.withValues(alpha: 0.3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.groups, color: Colors.blue, size: 20),
                    ),
                    title: const Text('Groups'),
                    subtitle: const Text('Join interest-based groups'),
                    trailing: _buildComingSoonBadge(),
                    onTap: () {
                      showComingSoonDialog(
                        context,
                        featureName: 'Groups',
                        description: 'Create and join interest-based groups to connect with like-minded people.',
                        icon: Icons.groups,
                        color: Colors.blue,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.withValues(alpha: 0.3), Colors.teal.withValues(alpha: 0.3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_stories, color: Colors.green, size: 20),
                    ),
                    title: const Text('Stories'),
                    subtitle: const Text('Share your moments'),
                    trailing: _buildComingSoonBadge(),
                    onTap: () {
                      showComingSoonDialog(
                        context,
                        featureName: 'Stories',
                        description: 'Share photos and videos that disappear after 24 hours with your connections.',
                        icon: Icons.auto_stories,
                        color: Colors.green,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Support Section
              _buildSectionHeader(
                icon: CupertinoIcons.question_circle_fill,
                title: 'Support',
                color: AppColors.iosTeal,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildSettingsCard(
                isDark: isDark,
                isGlass: isGlass,
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help Center'),
                    subtitle: const Text('Get help and support'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpCenterScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Safety Tips'),
                    subtitle: const Text('Stay safe while connecting'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SafetyTipsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: const Text('Invite Friends'),
                    subtitle: const Text('Share Supper with friends'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _shareApp();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    subtitle: const Text('Version 1.0.0'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showAboutDialog(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    subtitle: const Text('Read our terms of service'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsOfServiceScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('Read our privacy policy'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('Send Feedback'),
                    subtitle: const Text('Help us improve the app'),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showFeedbackDialog(context);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Report a Problem'),
                    subtitle: const Text(
                      'Let us know if something isn\'t working',
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    onTap: () {
                      _showReportProblemDialog(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ],
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required bool isDark,
    required bool isGlass,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isGlass ? 20 : 0,
          sigmaY: isGlass ? 20 : 0,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGlass
                  ? [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.3),
                    ]
                  : isDark
                  ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                  : [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGlass
                  ? Colors.white.withValues(alpha: 0.3)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.logout, color: Colors.red, size: 20),
      ),
      title: const Text(
        'Logout',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
      subtitle: Text(
        FirebaseAuth.instance.currentUser?.email ?? '',
        style: const TextStyle(fontSize: 14),
      ),
      trailing: const Icon(CupertinoIcons.chevron_forward, color: Colors.red),
      onTap: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Capture navigator before popping dialog
                  final navigator = Navigator.of(context, rootNavigator: true);
                  Navigator.pop(context);
                  await authService.signOut();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const ChooseAccountTypeScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Blocked Users
  void _showBlockedUsers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Blocked Users')),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('blocked')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final blockedUsers = snapshot.data!.docs;

              if (blockedUsers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Blocked Users',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: blockedUsers.length,
                itemBuilder: (context, index) {
                  final blockedUser = blockedUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(blockedUser['name']?[0] ?? 'U'),
                    ),
                    title: Text(blockedUser['name'] ?? 'Unknown'),
                    trailing: TextButton(
                      onPressed: () async {
                        await _firestore
                            .collection('users')
                            .doc(_currentUserId)
                            .collection('blocked')
                            .doc(blockedUser.id)
                            .delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User unblocked')),
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
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
        title: const Text('Security'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(
                Icons.lock_outline,
                color: hasPassword ? null : Colors.grey,
              ),
              title: Text(
                'Change Password',
                style: TextStyle(color: hasPassword ? null : Colors.grey),
              ),
              subtitle: Text(
                hasPassword
                    ? 'Update your password'
                    : signInMethod == 'google.com'
                    ? 'You signed in with Google'
                    : 'Not available for your account type',
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: hasPassword ? null : Colors.grey,
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
                            title: const Text('Google Account'),
                            content: const Text(
                              'You signed in with Google. To change your password, please:\n\n'
                              '1. Go to myaccount.google.com\n'
                              '2. Navigate to Security\n'
                              '3. Select "Password"\n'
                              '4. Follow Google\'s password change process\n\n'
                              'Your Google password will automatically work with this app.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.orange),
              ),
              subtitle: Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.orange),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context, authService);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Permanently delete',
                style: TextStyle(fontSize: 12),
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
            child: const Text('Close'),
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Capture navigator before popping dialog
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context);
              await authService.signOut();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const ChooseAccountTypeScreen(),
                ),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Logout'),
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
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. All your data will be permanently deleted.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            const Text('Type "DELETE" to confirm:'),
            const SizedBox(height: 10),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Delete Forever'),
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
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculating storage...'),
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
            title: const Text('Storage & Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('App Data'),
                  subtitle: Text(
                    '${(appSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cached_outlined),
                  title: const Text('Cache'),
                  subtitle: Text(
                    '${(cacheSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Total Storage'),
                  subtitle: Text(
                    '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
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
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear temporary files and cached images. Your account data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
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
            child: const Text('Clear'),
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
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'d love to hear your thoughts!'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Share your feedback here...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text('Send'),
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
            title: const Text('Report a Problem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Problem Type',
                  ),
                  items: ['Bug', 'Crash', 'Feature Request', 'Other']
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: problemController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Describe the problem...',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
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
                child: const Text('Submit'),
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
          colors: [Colors.purple.withValues(alpha: 0.8), Colors.blue.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'SOON',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Share app function
  void _shareApp() {
    Share.share(
      'Check out Supper - the AI-powered matching app that connects you with the right people! Download now: https://supper.app',
      subject: 'Join me on Supper!',
    );
  }

  // About dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.withValues(alpha: 0.6), Colors.blue.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supper',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
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
              'Supper is an AI-powered matching app that connects people for various purposes - marketplace, dating, friendship, jobs, and more.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.copyright, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  '2024 Supper Inc. All rights reserved.',
                  style: TextStyle(
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
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
