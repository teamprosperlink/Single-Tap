import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../config/business_category_config.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';
import 'business_setup_screen.dart';
import 'business_settings_screen.dart';

/// Public profile view tab that shows how customers see the business
///
/// Displays:
/// - Cover image with profile photo overlay
/// - Business name and category
/// - Rating (4.8 stars)
/// - Contact and Share buttons
/// - About section
/// - Popular items grid (Products/Menu/Rooms/Services)
class BusinessPublicProfileTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const BusinessPublicProfileTab({
    super.key,
    required this.business,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<BusinessPublicProfileTab> createState() => _BusinessPublicProfileTabState();
}

class _BusinessPublicProfileTabState extends State<BusinessPublicProfileTab> {
  final BusinessService _businessService = BusinessService();

  BusinessCategory get _category {
    return BusinessCategoryExtension.fromBusinessType(widget.business.businessType);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F0F23),
                ],
              ),
            ),
          ),
        ),

        // Main content
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Cover image with profile
            SliverToBoxAdapter(
              child: _buildCoverSection(),
            ),

            // Profile actions
            SliverToBoxAdapter(
              child: _buildProfileActions(),
            ),

            // Business info
            SliverToBoxAdapter(
              child: _buildBusinessInfo(),
            ),

            // About section
            SliverToBoxAdapter(
              child: _buildAboutSection(),
            ),

            // Popular items
            SliverToBoxAdapter(
              child: _buildPopularItems(),
            ),

            // Quick settings
            SliverToBoxAdapter(
              child: _buildQuickSettings(),
            ),

            // Logout button
            SliverToBoxAdapter(
              child: _buildLogoutSection(),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),

        // Settings button (top right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: _buildSettingsButton(),
        ),
      ],
    );
  }

  Widget _buildCoverSection() {
    return Stack(
      children: [
        // Cover image
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00D67D),
                const Color(0xFF00D67D).withValues(alpha: 0.7),
                const Color(0xFF00A86B),
              ],
            ),
          ),
          child: widget.business.coverImage != null
              ? Image.network(
                  widget.business.coverImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                )
              : _buildCoverPlaceholder(),
        ),

        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF1A1A2E),
                ],
              ),
            ),
          ),
        ),

        // Profile photo
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                width: 100,
                height: 100,
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
            ),
          ),
        ),

        // Edit cover button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: _buildEditCoverButton(),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D67D),
            const Color(0xFF00A86B),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _category.contentTabIcon,
          size: 60,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: const Color(0xFF00D67D),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEditCoverButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Edit Cover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessSettingsScreen(
                  business: widget.business,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          // Business name
          Text(
            widget.business.businessName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _category.contentTabIcon,
                  size: 14,
                  color: const Color(0xFF00D67D),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.business.businessType,
                  style: const TextStyle(
                    color: Color(0xFF00D67D),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                final rating = widget.business.rating;
                if (index < rating.floor()) {
                  return const Icon(Icons.star, color: Colors.amber, size: 20);
                } else if (index < rating) {
                  return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                } else {
                  return Icon(Icons.star_border, color: Colors.amber.withValues(alpha: 0.5), size: 20);
                }
              }),
              const SizedBox(width: 8),
              Text(
                '${widget.business.rating.toStringAsFixed(1)} (${widget.business.reviewCount} reviews)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => _editProfile(),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => _shareProfile(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF00D67D)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GlassmorphicCard(
        child: Column(
          children: [
            if (widget.business.address != null)
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: widget.business.address!.formattedAddress,
                color: Colors.blue,
              ),
            if (widget.business.contact.phone != null)
              _buildInfoRow(
                icon: Icons.phone_outlined,
                title: 'Phone',
                value: widget.business.contact.phone!,
                color: Colors.green,
                showDivider: widget.business.contact.email != null,
              ),
            if (widget.business.contact.email != null)
              _buildInfoRow(
                icon: Icons.email_outlined,
                title: 'Email',
                value: widget.business.contact.email!,
                color: Colors.orange,
                showDivider: widget.business.hours != null,
              ),
            if (widget.business.hours != null)
              _buildInfoRow(
                icon: Icons.access_time,
                title: 'Hours',
                value: widget.business.hours!.isCurrentlyOpen ? 'Open now' : 'Closed',
                valueColor: widget.business.hours!.isCurrentlyOpen
                    ? Colors.green
                    : Colors.red,
                color: Colors.purple,
                showDivider: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    Color? valueColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            color: Colors.white.withValues(alpha: 0.1),
            height: 1,
          ),
      ],
    );
  }

  Widget _buildAboutSection() {
    if (widget.business.description == null || widget.business.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          GlassmorphicCard(
            child: Text(
              widget.business.description!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularItems() {
    final terminology = CategoryTerminology.getForCategory(_category);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular ${terminology.filter1Label}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full list
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Color(0xFF00D67D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<BusinessListing>>(
            stream: _businessService.watchBusinessListings(widget.business.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                );
              }

              final items = snapshot.data ?? [];
              final displayItems = items.take(4).toList();

              if (displayItems.isEmpty) {
                return _buildEmptyPopularItems(terminology);
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];
                  return _buildPopularItemCard(item);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPopularItems(CategoryTerminology terminology) {
    return GlassmorphicCard(
      child: SizedBox(
        height: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _category.contentTabIcon,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${terminology.filter1Label.toLowerCase()} yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Navigate to add items
              },
              child: Text(
                terminology.addButtonLabel,
                style: const TextStyle(color: Color(0xFF00D67D)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularItemCard(BusinessListing item) {
    return GlassmorphicCard(
      padding: EdgeInsets.zero,
      onTap: () {
        // Show item details
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: item.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.network(
                        item.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildItemPlaceholder(),
                      ),
                    )
                  : _buildItemPlaceholder(),
            ),
          ),
          // Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPlaceholder() {
    return Center(
      child: Icon(
        _category.contentTabIcon,
        size: 30,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildQuickSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          GlassmorphicCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.qr_code_2,
                  title: 'QR Code',
                  subtitle: 'Generate shareable QR code',
                  onTap: () {
                    // Generate QR
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage notification settings',
                  onTap: () {
                    // Notifications
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics',
                  subtitle: 'View business insights',
                  onTap: () {
                    // Analytics
                  },
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF00D67D), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
            ),
          ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _confirmLogout();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.red.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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

  void _shareProfile() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text('Logout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout from your business account?',
          style: TextStyle(color: Colors.white70),
        ),
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
