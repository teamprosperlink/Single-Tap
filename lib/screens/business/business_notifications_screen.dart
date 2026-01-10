import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen for managing business notification settings
class BusinessNotificationsScreen extends StatefulWidget {
  const BusinessNotificationsScreen({super.key});

  @override
  State<BusinessNotificationsScreen> createState() => _BusinessNotificationsScreenState();
}

class _BusinessNotificationsScreenState extends State<BusinessNotificationsScreen> {
  bool _isLoading = true;

  // Push notifications
  bool _newInquiries = true;
  bool _messages = true;
  bool _reviews = true;
  bool _orderUpdates = true;

  // Email notifications
  bool _weeklySummary = true;
  bool _marketingUpdates = false;
  bool _tips = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _newInquiries = prefs.getBool('notif_new_inquiries') ?? true;
      _messages = prefs.getBool('notif_messages') ?? true;
      _reviews = prefs.getBool('notif_reviews') ?? true;
      _orderUpdates = prefs.getBool('notif_order_updates') ?? true;
      _weeklySummary = prefs.getBool('notif_weekly_summary') ?? true;
      _marketingUpdates = prefs.getBool('notif_marketing') ?? false;
      _tips = prefs.getBool('notif_tips') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF00D67D),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stay updated with important business activities',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Push Notifications Section
                  _buildSectionTitle('Push Notifications', isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(isDarkMode, [
                    _buildToggleTile(
                      icon: Icons.inbox_outlined,
                      title: 'New Inquiries',
                      subtitle: 'Get notified when customers send inquiries',
                      value: _newInquiries,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _newInquiries = value);
                        _saveSetting('notif_new_inquiries', value);
                      },
                    ),
                    _buildDivider(isDarkMode),
                    _buildToggleTile(
                      icon: Icons.chat_outlined,
                      title: 'Messages',
                      subtitle: 'Get notified for new messages',
                      value: _messages,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _messages = value);
                        _saveSetting('notif_messages', value);
                      },
                    ),
                    _buildDivider(isDarkMode),
                    _buildToggleTile(
                      icon: Icons.star_outline,
                      title: 'Reviews',
                      subtitle: 'Get notified when customers leave reviews',
                      value: _reviews,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _reviews = value);
                        _saveSetting('notif_reviews', value);
                      },
                    ),
                    _buildDivider(isDarkMode),
                    _buildToggleTile(
                      icon: Icons.sync_outlined,
                      title: 'Status Updates',
                      subtitle: 'Get updates on inquiry status changes',
                      value: _orderUpdates,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _orderUpdates = value);
                        _saveSetting('notif_order_updates', value);
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Email Notifications Section
                  _buildSectionTitle('Email Notifications', isDarkMode),
                  const SizedBox(height: 12),
                  _buildSettingsCard(isDarkMode, [
                    _buildToggleTile(
                      icon: Icons.summarize_outlined,
                      title: 'Weekly Summary',
                      subtitle: 'Receive weekly business performance summary',
                      value: _weeklySummary,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _weeklySummary = value);
                        _saveSetting('notif_weekly_summary', value);
                      },
                    ),
                    _buildDivider(isDarkMode),
                    _buildToggleTile(
                      icon: Icons.campaign_outlined,
                      title: 'Marketing Updates',
                      subtitle: 'Receive promotional offers and updates',
                      value: _marketingUpdates,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _marketingUpdates = value);
                        _saveSetting('notif_marketing', value);
                      },
                    ),
                    _buildDivider(isDarkMode),
                    _buildToggleTile(
                      icon: Icons.lightbulb_outline,
                      title: 'Tips & Suggestions',
                      subtitle: 'Receive tips to improve your business',
                      value: _tips,
                      isDarkMode: isDarkMode,
                      onChanged: (value) {
                        setState(() => _tips = value);
                        _saveSetting('notif_tips', value);
                      },
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
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

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 64,
      color: isDarkMode ? Colors.white12 : Colors.grey[200],
    );
  }
}
