import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern Location Section with Interactive Map
/// Features:
/// - Interactive map preview (static for now)
/// - Tap to expand full map
/// - Multiple navigation app options
/// - Distance and time estimate
/// - Copy address button
class ModernLocationSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ModernLocationSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (business.address == null || business.address!.formattedAddress.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header
        BusinessProfileComponents.modernSectionHeader(
          title: 'Location',
          isDarkMode: isDarkMode,
          icon: Icons.location_on,
        ),

        const SizedBox(height: 16),

        // Location card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(isDarkMode),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Map preview
              if (business.address?.latitude != null && business.address?.longitude != null)
                _buildMapPreview(context, isDarkMode),

              // Address details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place,
                          size: 20,
                          color: config.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                business.address!.formattedAddress,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkText(isDarkMode),
                                  height: 1.4,
                                ),
                              ),
                              if (business.address!.city != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${business.address!.city}${business.address!.state != null ? ', ${business.address!.state}' : ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.secondaryText(isDarkMode),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Copy button
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 18,
                            color: AppTheme.secondaryText(isDarkMode),
                          ),
                          onPressed: () => _copyAddress(context),
                          tooltip: 'Copy address',
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Navigation buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildNavigationButton(
                            context,
                            'Google Maps',
                            Icons.map,
                            config.primaryColor,
                            isDarkMode,
                            () => _openGoogleMaps(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNavigationButton(
                            context,
                            'Apple Maps',
                            Icons.navigation,
                            config.accentColor,
                            isDarkMode,
                            () => _openAppleMaps(),
                          ),
                        ),
                      ],
                    ),

                    // Distance info (placeholder)
                    if (business.address?.latitude != null && business.address?.longitude != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              size: 16,
                              color: AppTheme.infoBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap navigation button for directions',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.infoBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMapPreview(BuildContext context, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _openMap(context),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.secondaryText(isDarkMode).withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusLarge),
            topRight: Radius.circular(AppTheme.radiusLarge),
          ),
        ),
        child: Stack(
          children: [
            // Placeholder map (static image or pattern)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 64,
                    color: config.primaryColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view map',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryText(isDarkMode),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Expand button overlay
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: config.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isDarkMode,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMap(BuildContext context) {
    if (business.address?.latitude == null || business.address?.longitude == null) return;
    _openGoogleMaps();
  }

  void _openGoogleMaps() async {
    if (business.address?.latitude == null || business.address?.longitude == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${business.address!.latitude},${business.address!.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openAppleMaps() async {
    if (business.address?.latitude == null || business.address?.longitude == null) return;

    final url = Uri.parse(
      'https://maps.apple.com/?q=${business.address!.latitude},${business.address!.longitude}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _copyAddress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: business.address!.formattedAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Address copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
