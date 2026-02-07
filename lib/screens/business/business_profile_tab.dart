import 'package:flutter/material.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';
import 'business_setup_screen.dart';
import 'bank_account_screen.dart';
import 'business_addresses_screen.dart';
import 'business_hours_screen.dart';
import 'business_notifications_screen.dart';
import 'business_privacy_screen.dart';
import 'business_terms_screen.dart';
import 'business_support_screen.dart';

/// Profile tab showing business info, bank details, and settings
class BusinessProfileTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const BusinessProfileTab({
    super.key,
    required this.business,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<BusinessProfileTab> createState() => _BusinessProfileTabState();
}

class _BusinessProfileTabState extends State<BusinessProfileTab> {
  final BusinessService _businessService = BusinessService();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App Bar with profile header
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(isDarkMode),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => _editProfile(),
              ),
            ],
          ),

          // Profile content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Your Information Section
                _buildSectionTitle('Your Information', isDarkMode),
                const SizedBox(height: 12),
                _buildInfoSection(isDarkMode),
                const SizedBox(height: 24),

                // Payment Section
                _buildSectionTitle('Payment', isDarkMode),
                const SizedBox(height: 12),
                _buildPaymentSection(isDarkMode),
                const SizedBox(height: 24),

                // Settings Section
                _buildSectionTitle('Settings', isDarkMode),
                const SizedBox(height: 12),
                _buildSettingsSection(isDarkMode),
                const SizedBox(height: 24),

                // Danger Zone
                _buildDangerZone(isDarkMode),
                const SizedBox(height: 24),

                // Logout button
                _buildLogoutButton(isDarkMode),

                // Version
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Version 2.0.1',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDarkMode) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00D67D),
                const Color(0xFF00D67D).withValues(alpha: 0.7),
              ],
            ),
          ),
        ),

        // Profile content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.business.logo != null
                        ? Image.network(
                            widget.business.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildLogoPlaceholder(),
                          )
                        : _buildLogoPlaceholder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.business.businessName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.business.contact.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.business.contact.email!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            BusinessTypes.getIcon(widget.business.businessType),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.business.businessType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.business.isVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00D67D),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white70 : Colors.grey[700],
      ),
    );
  }

  Widget _buildInfoSection(bool isDarkMode) {
    return GlassmorphicContainer(
      child: Column(
        children: [
          GlassmorphicListTile(
            icon: Icons.location_on_outlined,
            title: 'Saved Addresses',
            subtitle: widget.business.address?.formattedAddress ?? 'Add address',
            onTap: () => _navigateToAddresses(),
            showDivider: true,
          ),
          GlassmorphicListTile(
            icon: Icons.phone_outlined,
            title: 'Contact Info',
            subtitle: widget.business.contact.phone ?? 'Add phone number',
            onTap: () => _editProfile(),
            showDivider: true,
          ),
          GlassmorphicListTile(
            icon: Icons.access_time,
            title: 'Business Hours',
            subtitle: widget.business.hours?.isCurrentlyOpen ?? false ? 'Open now' : 'Closed',
            iconColor: widget.business.hours?.isCurrentlyOpen ?? false ? Colors.green : Colors.orange,
            onTap: () => _navigateToHours(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(bool isDarkMode) {
    final hasBank = widget.business.bankAccount != null;

    return GlassmorphicContainer(
      child: GlassmorphicListTile(
        icon: Icons.account_balance_outlined,
        title: 'Bank Account',
        subtitle: hasBank
            ? '${widget.business.bankAccount!.bankName} ${widget.business.bankAccount!.maskedAccountNumber}'
            : 'Add bank account',
        trailing: hasBank && widget.business.bankAccount!.isVerified
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        onTap: () => _navigateToBankAccount(),
      ),
    );
  }

  Widget _buildSettingsSection(bool isDarkMode) {
    return GlassmorphicContainer(
      child: Column(
        children: [
          GlassmorphicListTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            iconColor: Colors.orange,
            onTap: () => _navigateToNotifications(),
            showDivider: true,
          ),
          GlassmorphicListTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Privacy and security settings',
            iconColor: Colors.blue,
            onTap: () => _navigateToPrivacy(),
            showDivider: true,
          ),
          GlassmorphicListTile(
            icon: Icons.article_outlined,
            title: 'Terms & Conditions',
            subtitle: 'View terms of service',
            iconColor: Colors.purple,
            onTap: () => _navigateToTerms(),
            showDivider: true,
          ),
          GlassmorphicListTile(
            icon: Icons.help_outline,
            title: 'Support',
            subtitle: 'Get help and contact us',
            iconColor: Colors.teal,
            onTap: () => _navigateToSupport(),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danger Zone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red[400],
          ),
        ),
        const SizedBox(height: 12),
        GlassmorphicCard(
          borderColor: Colors.red.withValues(alpha: 0.3),
          child: GlassmorphicListTile(
            icon: Icons.delete_forever_outlined,
            iconColor: Colors.red,
            title: 'Delete Business',
            subtitle: 'Permanently delete your business profile',
            onTap: () => _confirmDeleteBusiness(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(bool isDarkMode) {
    return GlassmorphicButton(
      icon: Icons.logout,
      label: 'Logout',
      color: Colors.red,
      expanded: true,
      onTap: () => _confirmLogout(),
    );
  }

  void _editProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessSetupScreen(
          existingBusiness: widget.business,
          onComplete: () {
            Navigator.pop(context, true);
          },
        ),
      ),
    );

    if (result == true) {
      widget.onRefresh();
    }
  }

  void _navigateToBankAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BankAccountScreen(
          business: widget.business,
        ),
      ),
    );

    if (result == true) {
      widget.onRefresh();
    }
  }

  void _navigateToAddresses() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessAddressesScreen(
          business: widget.business,
        ),
      ),
    );

    if (result == true) {
      widget.onRefresh();
    }
  }

  void _navigateToHours() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessHoursScreen(
          business: widget.business,
        ),
      ),
    );

    if (result == true) {
      widget.onRefresh();
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BusinessNotificationsScreen(),
      ),
    );
  }

  void _navigateToPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessPrivacyScreen(
          business: widget.business,
        ),
      ),
    );
  }

  void _navigateToTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BusinessTermsScreen(),
      ),
    );
  }

  void _navigateToSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BusinessSupportScreen(),
      ),
    );
  }

  void _confirmDeleteBusiness() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Business?'),
        content: const Text(
          'This will permanently delete your business profile and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _businessService.deleteBusiness(widget.business.id);
              if (success && mounted) {
                widget.onLogout();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout from your business account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
