import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/business_model.dart';
import '../../models/user_profile.dart';
import '../../services/business_service.dart';
import '../../services/account_type_service.dart';
import '../../res/config/app_colors.dart';
import 'business_setup_screen.dart';

/// Settings screen for business profile management
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  final BusinessModel business;

  const BusinessSettingsScreen({
    super.key,
    required this.business,
  });

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends ConsumerState<BusinessSettingsScreen> {
  final BusinessService _businessService = BusinessService();
  final AccountTypeService _accountTypeService = AccountTypeService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Business Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Profile Section
                  _buildSectionHeader('Business Profile', Icons.business, isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildSettingsTile(
                        icon: Icons.edit_outlined,
                        title: 'Edit Business Profile',
                        subtitle: 'Update your business information',
                        color: const Color(0xFF00D67D),
                        isDarkMode: isDarkMode,
                        onTap: _editBusinessProfile,
                      ),
                      _buildDivider(isDarkMode),
                      _buildSettingsTile(
                        icon: Icons.image_outlined,
                        title: 'Update Logo',
                        subtitle: 'Change your business logo',
                        color: Colors.blue,
                        isDarkMode: isDarkMode,
                        onTap: _updateLogo,
                      ),
                      _buildDivider(isDarkMode),
                      _buildSettingsTile(
                        icon: Icons.photo_library_outlined,
                        title: 'Update Cover Image',
                        subtitle: 'Change your cover photo',
                        color: Colors.purple,
                        isDarkMode: isDarkMode,
                        onTap: _updateCoverImage,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Business Hours Section
                  _buildSectionHeader('Business Hours', Icons.access_time, isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildSettingsTile(
                        icon: Icons.schedule_outlined,
                        title: 'Operating Hours',
                        subtitle: widget.business.hours?.isCurrentlyOpen ?? false
                            ? 'Currently Open'
                            : 'Currently Closed',
                        color: Colors.orange,
                        isDarkMode: isDarkMode,
                        onTap: _editBusinessHours,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Visibility Section
                  _buildSectionHeader('Visibility', Icons.visibility, isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildSwitchTile(
                        icon: Icons.storefront_outlined,
                        title: 'Business Active',
                        subtitle: 'Show your business to customers',
                        value: widget.business.isActive,
                        color: const Color(0xFF00D67D),
                        isDarkMode: isDarkMode,
                        onChanged: _toggleBusinessActive,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Account Section
                  _buildSectionHeader('Account', Icons.account_circle, isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDarkMode: isDarkMode,
                    children: [
                      _buildSettingsTile(
                        icon: Icons.swap_horiz,
                        title: 'Switch to Personal Account',
                        subtitle: 'Go back to your personal profile',
                        color: AppColors.iosBlue,
                        isDarkMode: isDarkMode,
                        onTap: _switchToPersonal,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Danger Zone
                  _buildSectionHeader('Danger Zone', Icons.warning_amber, isDarkMode, isDestructive: true),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    isDarkMode: isDarkMode,
                    isDestructive: true,
                    children: [
                      _buildSettingsTile(
                        icon: Icons.delete_forever_outlined,
                        title: 'Delete Business',
                        subtitle: 'Permanently delete your business profile',
                        color: Colors.red,
                        isDarkMode: isDarkMode,
                        isDestructive: true,
                        onTap: _confirmDeleteBusiness,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDarkMode, {bool isDestructive = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDestructive ? Colors.red : (isDarkMode ? Colors.white70 : Colors.grey[700]),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDestructive ? Colors.red : (isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required bool isDarkMode,
    required List<Widget> children,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDestructive
            ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDarkMode ? Colors.white38 : Colors.grey[400],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required bool isDarkMode,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: (newValue) {
          HapticFeedback.lightImpact();
          onChanged(newValue);
        },
        activeTrackColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
        activeThumbColor: const Color(0xFF00D67D),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 76,
      color: isDarkMode ? Colors.white12 : Colors.grey[200],
    );
  }

  void _editBusinessProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessSetupScreen(
          existingBusiness: widget.business,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true); // Return to dashboard with refresh flag
    }
  }

  void _updateLogo() async {
    // Navigate to edit with focus on logo
    _editBusinessProfile();
  }

  void _updateCoverImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cover image update coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _editBusinessHours() async {
    // For now, redirect to business edit
    _editBusinessProfile();
  }

  void _toggleBusinessActive(bool isActive) async {
    setState(() => _isLoading = true);

    try {
      final updatedBusiness = BusinessModel(
        id: widget.business.id,
        userId: widget.business.userId,
        businessName: widget.business.businessName,
        businessType: widget.business.businessType,
        contact: widget.business.contact,
        isActive: isActive,
        logo: widget.business.logo,
        coverImage: widget.business.coverImage,
        description: widget.business.description,
        industry: widget.business.industry,
        legalName: widget.business.legalName,
        address: widget.business.address,
        hours: widget.business.hours,
        rating: widget.business.rating,
        reviewCount: widget.business.reviewCount,
        followerCount: widget.business.followerCount,
        isVerified: widget.business.isVerified,
      );

      final success = await _businessService.updateBusiness(
        widget.business.id,
        updatedBusiness,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive
                ? 'Business is now visible to customers'
                : 'Business is now hidden from customers'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return with refresh flag
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _switchToPersonal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Switch to Personal?'),
        content: const Text(
          'This will switch your account to personal mode. Your business profile will remain saved and you can switch back anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
            ),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);

      final success = await _accountTypeService.upgradeAccountType(AccountType.personal);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Personal Account'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to main navigation
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDeleteBusiness() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Business?'),
          ],
        ),
        content: const Text(
          'This action cannot be undone. All your business data, listings, and reviews will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);

      final success = await _businessService.deleteBusiness(widget.business.id);

      if (success && mounted) {
        // Switch back to personal account
        await _accountTypeService.upgradeAccountType(AccountType.personal);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to main navigation
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete business'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
