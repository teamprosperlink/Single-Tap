import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import 'business_analytics_screen.dart';
import 'business_inquiries_screen.dart';
import 'business_services_tab.dart';
import 'business_posts_tab.dart';

/// Home tab showing dashboard with stats, online toggle, and quick actions
class BusinessHomeTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;
  final Function(int) onSwitchTab;

  const BusinessHomeTab({
    super.key,
    required this.business,
    required this.onRefresh,
    required this.onSwitchTab,
  });

  @override
  State<BusinessHomeTab> createState() => _BusinessHomeTabState();
}

class _BusinessHomeTabState extends State<BusinessHomeTab> {
  final BusinessService _businessService = BusinessService();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.business.isOnline;
  }

  @override
  void didUpdateWidget(BusinessHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.isOnline != widget.business.isOnline) {
      _isOnline = widget.business.isOnline;
    }
  }

  Future<void> _toggleOnlineStatus() async {
    HapticFeedback.lightImpact();
    final newStatus = !_isOnline;
    setState(() => _isOnline = newStatus);

    try {
      await _businessService.updateOnlineStatus(widget.business.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'You are now online' : 'You are now offline'),
            backgroundColor: newStatus ? Colors.green : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      setState(() => _isOnline = !newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Background Image (same as Feed screen)
        Positioned.fill(
          child: Image.asset(
            AppAssets.homeBackgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(color: AppColors.darkOverlay()),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header (same style as Feed screen)
              _buildAppBarHeader(),

              // Divider line
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),

              // Scrollable content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => widget.onRefresh(),
                  color: const Color(0xFF00D67D),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Quick Actions - Services & Posts
                      _buildQuickActions(isDarkMode),
                      const SizedBox(height: 24),

                      // Stats Grid
                      _buildSectionTitle('Overview', isDarkMode),
                      const SizedBox(height: 12),
                      _buildStatsGrid(isDarkMode),
                      const SizedBox(height: 24),

                      // Analytics Preview
                      _buildAnalyticsPreview(isDarkMode),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Simple header like Feed screen
  Widget _buildAppBarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business logo
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: widget.business.logo != null
                  ? Image.network(
                      widget.business.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                    )
                  : _buildLogoPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),

          // Business name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.business.businessName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _getLocationText(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Online/Offline toggle
          _buildOnlineToggleCompact(),

          const SizedBox(width: 8),

          // Notification button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Show notifications
            },
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocationText() {
    final address = widget.business.address;
    if (address == null) return 'Location not set';

    final parts = <String>[];
    if (address.city != null && address.city!.isNotEmpty) {
      parts.add(address.city!);
    }
    if (address.state != null && address.state!.isNotEmpty) {
      parts.add(address.state!);
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Location not set';
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00D67D),
      ),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Compact online/offline toggle for AppBar
  Widget _buildOnlineToggleCompact() {
    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.grey,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00D67D).withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          // Status text
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isOnline ? const Color(0xFF00D67D) : Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
          // Toggle icon - bigger size
          Icon(
            _isOnline ? Icons.toggle_on : Icons.toggle_off,
            size: 44,
            color: _isOnline ? const Color(0xFF00D67D) : Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Row(
      children: [
        // Services Button
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.inventory_2_outlined,
            label: 'Services',
            subtitle: 'Manage your services',
            gradient: [
              const Color(0xFF00D67D).withValues(alpha: 0.3),
              const Color(0xFF00A86B).withValues(alpha: 0.2),
            ],
            iconColor: const Color(0xFF00D67D),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessServicesTab(
                    business: widget.business,
                    onRefresh: widget.onRefresh,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Posts Button
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.post_add_outlined,
            label: 'Posts',
            subtitle: 'Create & manage posts',
            gradient: [
              Colors.blue.withValues(alpha: 0.3),
              Colors.indigo.withValues(alpha: 0.2),
            ],
            iconColor: Colors.blue,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessPostsTab(
                    business: widget.business,
                    onRefresh: widget.onRefresh,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with glow effect
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                // Label
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                // Arrow indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatsGrid(bool isDarkMode) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        GlassmorphicStatCard(
          title: 'Total Inquiries',
          value: '${widget.business.totalOrders}',
          icon: Icons.inbox_outlined,
          accentColor: const Color(0xFF00D67D),
          onTap: () => _navigateToInquiries('All'),
        ),
        GlassmorphicStatCard(
          title: 'New',
          value: '${widget.business.pendingOrders}',
          icon: Icons.mark_email_unread_outlined,
          accentColor: Colors.orange,
          onTap: () => _navigateToInquiries('New'),
        ),
        GlassmorphicStatCard(
          title: 'Responded',
          value: '${widget.business.completedOrders}',
          icon: Icons.check_circle_outline,
          accentColor: Colors.blue,
          onTap: () => _navigateToInquiries('Responded'),
        ),
        GlassmorphicStatCard(
          title: 'Today',
          value: '${widget.business.todayOrders}',
          icon: Icons.today,
          accentColor: Colors.purple,
          onTap: () => _navigateToInquiries('Today'),
        ),
      ],
    );
  }

  Widget _buildAnalyticsPreview(bool isDarkMode) {
    return GlassmorphicCard(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessAnalyticsScreen(business: widget.business),
          ),
        );
      },
      showGlow: true,
      glowColor: const Color(0xFF00D67D),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00D67D).withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Color(0xFF00D67D),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'See insights about your business',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInquiries(String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessInquiriesScreen(
          business: widget.business,
          initialFilter: filter,
        ),
      ),
    );
  }
}
