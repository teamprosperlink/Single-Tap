import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/business/business_profile_components.dart';

/// Modern About Section
/// Features:
/// - Clean card design
/// - Read more/less functionality
/// - Contact info badges
/// - Social media links
class ModernAboutSection extends StatefulWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const ModernAboutSection({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  State<ModernAboutSection> createState() => _ModernAboutSectionState();
}

class _ModernAboutSectionState extends State<ModernAboutSection> {
  bool _isExpanded = false;
  static const int _collapsedLength = 150;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final description = widget.business.description;

    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    final needsExpansion = description.length > _collapsedLength;
    final displayText = needsExpansion && !_isExpanded
        ? '${description.substring(0, _collapsedLength)}...'
        : description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Section header
        BusinessProfileComponents.modernSectionHeader(
          title: 'About',
          isDarkMode: isDarkMode,
          icon: Icons.info_outline,
        ),

        const SizedBox(height: 16),

        // About card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          padding: const EdgeInsets.all(20),
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
              // Description text
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.darkText(isDarkMode),
                  height: 1.6,
                ),
              ),

              // Read more/less button
              if (needsExpansion) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Read less' : 'Read more',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.config.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: widget.config.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],

              // Contact badges
              if (_hasContactInfo()) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.business.contact.phone != null &&
                        widget.business.contact.phone!.isNotEmpty)
                      _buildContactBadge(
                        Icons.phone,
                        widget.business.contact.phone!,
                        widget.config.primaryColor,
                        isDarkMode,
                      ),
                    if (widget.business.contact.email != null &&
                        widget.business.contact.email!.isNotEmpty)
                      _buildContactBadge(
                        Icons.email,
                        widget.business.contact.email!,
                        AppTheme.infoBlue,
                        isDarkMode,
                      ),
                    if (widget.business.contact.website != null &&
                        widget.business.contact.website!.isNotEmpty)
                      _buildContactBadge(
                        Icons.language,
                        'Website',
                        widget.config.accentColor,
                        isDarkMode,
                      ),
                  ],
                ),
              ],

              // Social media links
              if (_hasSocialMedia()) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Follow us:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText(isDarkMode),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ..._buildSocialIcons(isDarkMode),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContactBadge(
    IconData icon,
    String text,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkText(isDarkMode),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSocialIcons(bool isDarkMode) {
    final icons = <Widget>[];
    final socialLinks = widget.business.socialLinks;

    if (socialLinks['facebook'] != null) {
      icons.add(_buildSocialIcon(Icons.facebook, const Color(0xFF1877F2)));
    }
    if (socialLinks['instagram'] != null) {
      icons.add(_buildSocialIcon(Icons.camera_alt, const Color(0xFFE4405F)));
    }
    if (socialLinks['twitter'] != null) {
      icons.add(_buildSocialIcon(Icons.flutter_dash, const Color(0xFF1DA1F2)));
    }
    if (socialLinks['linkedin'] != null) {
      icons.add(_buildSocialIcon(Icons.business, const Color(0xFF0A66C2)));
    }

    return icons;
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  bool _hasContactInfo() {
    return (widget.business.contact.phone != null && widget.business.contact.phone!.isNotEmpty) ||
        (widget.business.contact.email != null && widget.business.contact.email!.isNotEmpty) ||
        (widget.business.contact.website != null && widget.business.contact.website!.isNotEmpty);
  }

  bool _hasSocialMedia() {
    return widget.business.socialLinks.isNotEmpty;
  }
}
