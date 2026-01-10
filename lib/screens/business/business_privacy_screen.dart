import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';

/// Screen for managing business privacy settings
class BusinessPrivacyScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessPrivacyScreen({
    super.key,
    required this.business,
  });

  @override
  State<BusinessPrivacyScreen> createState() => _BusinessPrivacyScreenState();
}

class _BusinessPrivacyScreenState extends State<BusinessPrivacyScreen> {
  final BusinessService _businessService = BusinessService();
  bool _isSaving = false;

  // Privacy settings
  late bool _publicProfile;
  late bool _showPhone;
  late bool _showEmail;
  late bool _showAddress;
  late bool _showHours;
  late bool _allowMessages;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  void _initSettings() {
    // Default to showing everything if not set
    _publicProfile = widget.business.isActive;
    _showPhone = true;
    _showEmail = true;
    _showAddress = true;
    _showHours = true;
    _allowMessages = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Visibility Section
            _buildSectionTitle('Profile Visibility', isDarkMode),
            const SizedBox(height: 12),
            _buildSettingsCard(isDarkMode, [
              _buildToggleTile(
                icon: Icons.visibility_outlined,
                title: 'Public Profile',
                subtitle: 'Allow your business to appear in search results',
                value: _publicProfile,
                isDarkMode: isDarkMode,
                onChanged: (value) async {
                  setState(() => _publicProfile = value);
                  await _updateBusinessSetting('isActive', value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Contact Information Section
            _buildSectionTitle('Contact Information', isDarkMode),
            const SizedBox(height: 12),
            _buildSettingsCard(isDarkMode, [
              _buildToggleTile(
                icon: Icons.phone_outlined,
                title: 'Show Phone Number',
                subtitle: 'Display your phone number on your profile',
                value: _showPhone,
                isDarkMode: isDarkMode,
                onChanged: (value) {
                  setState(() => _showPhone = value);
                },
              ),
              _buildDivider(isDarkMode),
              _buildToggleTile(
                icon: Icons.email_outlined,
                title: 'Show Email',
                subtitle: 'Display your email on your profile',
                value: _showEmail,
                isDarkMode: isDarkMode,
                onChanged: (value) {
                  setState(() => _showEmail = value);
                },
              ),
              _buildDivider(isDarkMode),
              _buildToggleTile(
                icon: Icons.location_on_outlined,
                title: 'Show Address',
                subtitle: 'Display your address on your profile',
                value: _showAddress,
                isDarkMode: isDarkMode,
                onChanged: (value) {
                  setState(() => _showAddress = value);
                },
              ),
              _buildDivider(isDarkMode),
              _buildToggleTile(
                icon: Icons.access_time,
                title: 'Show Business Hours',
                subtitle: 'Display your operating hours',
                value: _showHours,
                isDarkMode: isDarkMode,
                onChanged: (value) {
                  setState(() => _showHours = value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Communication Section
            _buildSectionTitle('Communication', isDarkMode),
            const SizedBox(height: 12),
            _buildSettingsCard(isDarkMode, [
              _buildToggleTile(
                icon: Icons.message_outlined,
                title: 'Allow Messages',
                subtitle: 'Let customers send you direct messages',
                value: _allowMessages,
                isDarkMode: isDarkMode,
                onChanged: (value) {
                  setState(() => _allowMessages = value);
                },
              ),
            ]),
            const SizedBox(height: 24),

            // Data & Privacy Info
            _buildSectionTitle('Data & Privacy', isDarkMode),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.download_outlined,
                    title: 'Download My Data',
                    subtitle: 'Get a copy of your business data',
                    isDarkMode: isDarkMode,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Data export will be sent to your email'),
                        ),
                      );
                    },
                  ),
                  _buildDivider(isDarkMode),
                  _buildInfoTile(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle: 'Manage account security settings',
                    isDarkMode: isDarkMode,
                    onTap: () {
                      // Navigate to security settings
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
          ),
          // Loading overlay
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00D67D),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateBusinessSetting(String key, dynamic value) async {
    setState(() => _isSaving = true);

    // Create updated business model based on the key being changed
    BusinessModel updatedBusiness;
    if (key == 'isActive') {
      updatedBusiness = widget.business.copyWith(isActive: value as bool);
    } else {
      // Default case - just update with current values
      updatedBusiness = widget.business.copyWith();
    }

    final success = await _businessService.updateBusiness(
      widget.business.id,
      updatedBusiness,
    );

    if (mounted) {
      setState(() => _isSaving = false);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update setting'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Widget _buildSettingsCard(bool isDarkMode, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDarkMode,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00D67D), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
            activeTrackColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
            activeThumbColor: const Color(0xFF00D67D),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF00D67D), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 64,
      color: isDarkMode ? Colors.white12 : Colors.grey[200],
    );
  }
}
