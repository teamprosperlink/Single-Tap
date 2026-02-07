import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying business location with map and address
class LocationSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const LocationSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final address = business.address;

    if (address == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 20,
                  color: config.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Static map preview
          if (address.hasCoordinates)
            GestureDetector(
              onTap: () => _openMaps(context),
              child: Container(
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode ? Colors.white10 : Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Static map image using Google Static Maps API
                      Image.network(
                        _getStaticMapUrl(address.latitude!, address.longitude!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildMapPlaceholder(isDarkMode);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildMapPlaceholder(isDarkMode);
                        },
                      ),
                      // Tap overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Map pin
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: config.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // View on Maps text
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View on Maps',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildMapPlaceholder(isDarkMode),

          // Address text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.formattedAddress,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                // Get Directions button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMaps(context),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Get Directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: config.primaryColor,
                      side: BorderSide(color: config.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(bool isDarkMode) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: config.primaryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 40,
              color: config.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to open in Maps',
              style: TextStyle(
                color: config.primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStaticMapUrl(double lat, double lng) {
    // Using OpenStreetMap static tiles as fallback
    // For production, use Google Static Maps API with your API key
    final zoom = 15;
    return 'https://maps.googleapis.com/maps/api/staticmap?'
        'center=$lat,$lng'
        '&zoom=$zoom'
        '&size=400x200'
        '&maptype=roadmap'
        '&markers=color:red%7C$lat,$lng'
        '&key=YOUR_GOOGLE_MAPS_API_KEY'; // Replace with actual API key
  }

  Future<void> _openMaps(BuildContext context) async {
    final address = business.address;
    if (address == null) return;

    Uri uri;
    if (address.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${address.latitude},${address.longitude}',
      );
    } else {
      final query = Uri.encodeComponent(address.formattedAddress);
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }
}

/// Contact section with all contact methods
class ContactSection extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ContactSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final contact = business.contact;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.contact_phone,
                  size: 20,
                  color: config.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (contact.phone != null)
            _ContactItem(
              icon: Icons.phone,
              label: 'Phone',
              value: contact.phone!,
              color: Colors.green,
              onTap: () => _makeCall(context, contact.phone!),
              isDarkMode: isDarkMode,
            ),
          if (contact.whatsapp != null)
            _ContactItem(
              icon: Icons.chat,
              label: 'WhatsApp',
              value: contact.whatsapp!,
              color: const Color(0xFF25D366),
              onTap: () => _openWhatsApp(context, contact.whatsapp!),
              isDarkMode: isDarkMode,
            ),
          if (contact.email != null)
            _ContactItem(
              icon: Icons.email,
              label: 'Email',
              value: contact.email!,
              color: Colors.blue,
              onTap: () => _sendEmail(context, contact.email!),
              isDarkMode: isDarkMode,
            ),
          if (contact.website != null)
            _ContactItem(
              icon: Icons.language,
              label: 'Website',
              value: contact.website!,
              color: Colors.purple,
              onTap: () => _openWebsite(context, contact.website!),
              isDarkMode: isDarkMode,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _makeCall(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite(BuildContext context, String website) async {
    var url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white24 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
