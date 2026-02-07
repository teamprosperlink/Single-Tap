import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../home/main_navigation_screen.dart';
import '../login/change_password_screen.dart';
import 'profile_edit_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/coming_soon_widget.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Toggle states
  bool _improveAI = true;
  bool _saveChatHistory = true;
  bool _thirdPartyIntegrations = false;

  // Loading state
  bool _isLoading = false;

  String? get _userId => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _improveAI = data['improveAI'] ?? true;
          _saveChatHistory = data['saveChatHistory'] ?? true;
          _thirdPartyIntegrations = data['thirdPartyIntegrations'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============ DATA CONTROL ACTIONS ============

  void _exportData() {
    showComingSoonDialog(
      context,
      featureName: 'Export Data',
      description: 'Download a copy of all your data including profile, messages, and activity.',
      icon: Icons.download_outlined,
    );
  }

  Future<void> _deleteChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat History', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all your AI chat conversations. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) return;

      // Delete all chat_history documents for this user
      final chatDocs = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: userId)
          .limit(500)
          .get();

      final batch = _firestore.batch();
      for (var doc in chatDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _showSnackBar('Chat history deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete chat history: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Memory', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear the app cache and temporary files. Your account data will not be affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Color(0xFF6366f1))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // Clear app cache directory
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        await for (var entity in cacheDir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }

      _showSnackBar('Memory cleared successfully');
    } catch (e) {
      _showSnackBar('Failed to clear memory: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ SECURITY ACTIONS ============

  void _changePassword() {
    if (!_authService.hasPasswordProvider()) {
      _showSnackBar(
        'Password change is only available for email/password accounts',
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out All Devices', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will sign out all other devices logged into your account. You will remain logged in on this device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _authService.logoutFromOtherDevices();
      _showSnackBar('All other devices have been logged out');
    } catch (e) {
      _showSnackBar('Failed to log out devices: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ ACCOUNT ACTIONS ============

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
  }

  Future<void> _deactivateAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Deactivate Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your account will be temporarily disabled. You can reactivate it by logging in again. Your data will be preserved.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'accountStatus': 'deactivated',
        'deactivatedAt': FieldValue.serverTimestamp(),
        'isOnline': false,
      });

      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showSnackBar('Failed to deactivate account: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete your account and ALL your data including messages, profile, and connections. This action CANNOT be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation with typed text
    final confirmController = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Type DELETE to confirm', style: TextStyle(color: Colors.red)),
        content: TextField(
          controller: confirmController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type DELETE',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (confirmController.text.trim().toUpperCase() == 'DELETE') {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    confirmController.dispose();
    if (secondConfirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final userId = _userId;
      if (userId == null) return;

      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete posts
      final posts = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .limit(500)
          .get();
      for (var doc in posts.docs) {
        await doc.reference.delete();
      }

      // Delete chat history
      final chatHistory = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: userId)
          .limit(500)
          .get();
      for (var doc in chatHistory.docs) {
        await doc.reference.delete();
      }

      // Delete Firebase Auth account
      await _authService.deleteAccount();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showSnackBar(
        'Failed to delete account. You may need to re-login and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
            });
          },
        ),
        title: const Text(
          'Personalization',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Data Control'),
                Tab(text: 'Security'),
                Tab(text: 'Account'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/logo/home_background.webp',
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

          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDataControlTab(),
                _buildSecurityTab(),
                _buildAccountTab(),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366f1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataControlTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionHeader('Data Management'),
        const SizedBox(height: 8),

        _buildSettingItem(
          icon: Icons.download_outlined,
          title: 'Export your data',
          subtitle: 'Download a copy of your data',
          onTap: _exportData,
        ),

        _buildSettingItem(
          icon: Icons.delete_outline,
          title: 'Delete chat history',
          subtitle: 'Remove all your conversations',
          onTap: _deleteChatHistory,
          isDestructive: true,
        ),

        _buildSettingItem(
          icon: Icons.memory_outlined,
          title: 'Clear memory',
          subtitle: 'Remove all saved memories',
          onTap: _clearMemory,
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('Privacy'),
        const SizedBox(height: 8),

        _buildToggleItem(
          icon: Icons.visibility_outlined,
          title: 'Improve AI for everyone',
          subtitle: 'Allow your data to help improve AI models',
          value: _improveAI,
          onChanged: (value) {
            setState(() => _improveAI = value);
            _updatePreference('improveAI', value);
          },
        ),

        _buildToggleItem(
          icon: Icons.history_outlined,
          title: 'Save chat history',
          subtitle: 'Keep a record of your conversations',
          value: _saveChatHistory,
          onChanged: (value) {
            setState(() => _saveChatHistory = value);
            _updatePreference('saveChatHistory', value);
          },
        ),

        _buildToggleItem(
          icon: Icons.link_outlined,
          title: 'Third-party integrations',
          subtitle: 'Allow connections to external apps',
          value: _thirdPartyIntegrations,
          onChanged: (value) {
            setState(() => _thirdPartyIntegrations = value);
            _updatePreference('thirdPartyIntegrations', value);
          },
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSettingItem(
          icon: Icons.lock_outline,
          title: 'Change password',
          subtitle: 'Update your account password',
          onTap: _changePassword,
        ),

        const SizedBox(height: 8),
        _buildSectionHeader('Sessions'),
        const SizedBox(height: 8),

        _buildSettingItem(
          icon: Icons.devices_outlined,
          title: 'Active sessions',
          subtitle: 'Manage devices logged into your account',
          onTap: () {
            showComingSoonDialog(
              context,
              featureName: 'Active Sessions',
              description: 'View and manage all devices where you are logged in.',
              icon: Icons.devices_outlined,
            );
          },
        ),

        _buildSettingItem(
          icon: Icons.logout,
          title: 'Log out all devices',
          subtitle: 'Sign out from all other devices',
          onTap: _logoutAllDevices,
          isDestructive: true,
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('Security Log'),
        const SizedBox(height: 8),

        _buildSettingItem(
          icon: Icons.history_outlined,
          title: 'Login history',
          subtitle: 'View recent login activity',
          onTap: () {
            showComingSoonDialog(
              context,
              featureName: 'Login History',
              description: 'View your recent login activity and device details.',
              icon: Icons.history_outlined,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildSectionHeader('Profile'),
        const SizedBox(height: 8),

        _buildSettingItem(
          icon: Icons.person_outline,
          title: 'Edit profile',
          subtitle: 'Update your name, photo, and bio',
          onTap: _editProfile,
        ),

        const SizedBox(height: 8),
        _buildSectionHeader('Danger Zone'),
        const SizedBox(height: 8),

        _buildSettingItem(
          icon: Icons.pause_circle_outline,
          title: 'Deactivate account',
          subtitle: 'Temporarily disable your account',
          onTap: _deactivateAccount,
          isDestructive: true,
        ),

        _buildSettingItem(
          icon: Icons.delete_forever_outlined,
          title: 'Delete account',
          subtitle: 'Permanently delete your account and data',
          onTap: _deleteAccount,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6366f1),
            activeTrackColor: const Color(0xFF6366f1).withValues(alpha: 0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
