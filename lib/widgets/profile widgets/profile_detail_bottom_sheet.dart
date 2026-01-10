import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/extended_user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/config/app_text_styles.dart';
import 'dart:math' as math;

class ProfileDetailBottomSheet extends StatefulWidget {
  final ExtendedUserProfile user;
  final VoidCallback? onConnect;
  final VoidCallback? onMessage;
  final VoidCallback? onEdit;
  final String? connectionStatus; // 'connected', 'sent', 'received', or null
  final bool isOwnProfile; // True if viewing own profile

  const ProfileDetailBottomSheet({
    super.key,
    required this.user,
    this.onConnect,
    this.onMessage,
    this.onEdit,
    this.connectionStatus,
    this.isOwnProfile = false,
  });

  @override
  State<ProfileDetailBottomSheet> createState() =>
      _ProfileDetailBottomSheetState();
}

class _ProfileDetailBottomSheetState extends State<ProfileDetailBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Gradient color movement animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate content height based on available sections
    final hasConnectionTypes = widget.user.connectionTypes.isNotEmpty;
    final hasActivities = widget.user.activities.isNotEmpty;
    final hasAbout =
        widget.user.aboutMe != null && widget.user.aboutMe!.isNotEmpty;
    final hasInterests = widget.user.interests.isNotEmpty;

    // Calculate initial size based on content
    double initialSize = 0.50;
    if (hasConnectionTypes) initialSize += 0.06;
    if (hasActivities) initialSize += 0.06;
    if (hasAbout) initialSize += 0.08;
    if (hasInterests) initialSize += 0.06;
    initialSize = initialSize.clamp(0.45, 0.75);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            // Subtle border for the entire card
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
              // Subtle glow effect
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle with gradient
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[500]!, Colors.grey[400]!],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium glass header with profile photo, name, status, and info
                      _buildPremiumHeader(context, isDarkMode),

                      const SizedBox(height: 24), // Increased spacing
                      // Content sections (chips with gradients)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Connection Types
                            if (hasConnectionTypes) ...[
                              _buildGradientChipsSection(
                                widget.user.connectionTypes,
                                _getConnectionTypeGradient,
                              ),
                              const SizedBox(height: 8), // Increased spacing
                            ],

                            // Activities
                            if (hasActivities) ...[
                              _buildGradientChipsSection(
                                widget.user.activities
                                    .map((a) => a.name)
                                    .toList(),
                                _getActivityGradient,
                              ),
                              const SizedBox(height: 8), // Increased spacing
                            ],

                            // About Me
                            if (hasAbout) ...[
                              _buildAbout(context, isDarkMode),
                              const SizedBox(height: 8), // Increased spacing
                            ],

                            // Interests
                            if (hasInterests)
                              _buildGradientChipsSection(
                                widget.user.interests,
                                _getInterestGradient,
                              ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons with gradient
              _buildActionButtons(context, isDarkMode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDarkMode) {
    return AnimatedBuilder(
      animation: _gradientController,
      builder: (context, child) {
        // Animated gradient alignment for color movement
        final animValue = _gradientController.value;
        final beginAlign = Alignment(
          -1.0 + (animValue * 0.5),
          -1.0 + (animValue * 0.3),
        );
        final endAlign = Alignment(
          1.0 - (animValue * 0.3),
          1.0 - (animValue * 0.5),
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Stack(
            children: [
              // Main header container with animated gradient
              Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                decoration: BoxDecoration(
                  // Premium vibrant purple-blue gradient like the reference
                  gradient: LinearGradient(
                    begin: beginAlign,
                    end: endAlign,
                    colors: const [
                      Color(0xFF7C3AED), // Violet
                      Color(0xFF8B5CF6), // Purple
                      Color(0xFFA855F7), // Light purple
                      Color(0xFF6366F1), // Indigo
                      Color(0xFF3B82F6), // Blue
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo with simple ring
                    _buildProfilePhoto(),
                    const SizedBox(width: 16),
                    // Name and Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(
                            widget.user.name,
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          // Connection status badge
                          if (widget.connectionStatus != null) ...[
                            const SizedBox(height: 8),
                            _buildConnectionStatusBadge(),
                          ],
                          // Info row: Distance, Age, Gender
                          if (_hasUserInfo()) ...[
                            const SizedBox(height: 8),
                            _buildUserInfoRow(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Subtle shimmer overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ShimmerPainter(
                          progress: _shimmerController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfilePhoto() {
    return Container(
      // Black border ring
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A1A), // Dark black border
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: const Color(0xFF2D2D44),
        backgroundImage: PhotoUrlHelper.isValidUrl(widget.user.photoUrl)
            ? CachedNetworkImageProvider(widget.user.photoUrl!)
            : null,
        child: !PhotoUrlHelper.isValidUrl(widget.user.photoUrl)
            ? Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name[0].toUpperCase()
                    : '?',
                style: AppTextStyles.displayMedium.copyWith(
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildGradientChipsSection(
    List<String> items,
    List<Color> Function(int) gradientGetter,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final gradientColors = gradientGetter(index);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              item,
              style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAbout(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF2A2A3E), const Color(0xFF252538)]
                : [const Color(0xFFF8F9FA), const Color(0xFFF1F3F4)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  'About',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.user.aboutMe!,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.6,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDarkMode) {
    // Show Edit button for own profile
    if (widget.isOwnProfile) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? const Color(0xFF38383A).withValues(alpha: 0.5)
                  : const Color(0xFFE5E5EA),
              width: 0.5,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: widget.onEdit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF7C3AED), // Violet
                  Color(0xFF8B5CF6), // Purple
                  Color(0xFFA855F7), // Light purple
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isConnected = widget.connectionStatus == 'connected';
    final isRequestSent = widget.connectionStatus == 'sent';
    final showOnlyMessage = isConnected || isRequestSent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF38383A).withValues(alpha: 0.5)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: showOnlyMessage
          // When connected or request sent - show only Message button (full width) with gradient
          ? GestureDetector(
              onTap: widget.onMessage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF3B82F6), // Blue
                      Color(0xFF6366F1), // Indigo
                      Color(0xFF8B5CF6), // Purple
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Message',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // When not connected - show Connect + Message buttons
          : Row(
              children: [
                // Connect Button with gradient
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onConnect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF10B981), // Green
                            Color(0xFF34D399), // Light green
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connect',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Message Button with gradient border
                GestureDetector(
                  onTap: widget.onMessage,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF1C1C1E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConnectionStatusBadge() {
    Color badgeColor;
    List<Color> gradientColors;
    String statusText;
    IconData statusIcon;

    switch (widget.connectionStatus) {
      case 'connected':
        gradientColors = [const Color(0xFF10B981), const Color(0xFF34D399)];
        badgeColor = const Color(0xFF10B981);
        statusText = 'Connected';
        statusIcon = Icons.check_circle;
        break;
      case 'sent':
        gradientColors = [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
        badgeColor = const Color(0xFFF59E0B);
        statusText = 'Request Sent';
        statusIcon = Icons.schedule;
        break;
      case 'received':
        gradientColors = [const Color(0xFF10B981), const Color(0xFF34D399)];
        badgeColor = const Color(0xFF10B981);
        statusText = 'Request Received';
        statusIcon = Icons.inbox;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            statusText,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasUserInfo() {
    return widget.user.distance != null ||
        widget.user.age != null ||
        widget.user.gender != null;
  }

  Widget _buildUserInfoRow() {
    final List<Widget> infoItems = [];

    // Distance
    if (widget.user.distance != null) {
      String distanceText;
      if (widget.user.distance! < 1) {
        distanceText = '${(widget.user.distance! * 1000).round()}m';
      } else {
        distanceText = '${widget.user.distance!.toStringAsFixed(1)}km';
      }
      infoItems.add(_buildInfoItem(Icons.near_me, distanceText));
    }

    // Age
    if (widget.user.age != null) {
      infoItems.add(
        _buildInfoItem(Icons.cake_outlined, '${widget.user.age} yrs'),
      );
    }

    // Gender
    if (widget.user.gender != null && widget.user.gender!.isNotEmpty) {
      IconData genderIcon;
      if (widget.user.gender == 'Male') {
        genderIcon = Icons.male;
      } else if (widget.user.gender == 'Female') {
        genderIcon = Icons.female;
      } else {
        genderIcon = Icons.person_outline;
      }
      infoItems.add(_buildInfoItem(genderIcon, widget.user.gender!));
    }

    if (infoItems.isEmpty) return const SizedBox.shrink();

    // Add separators
    final List<Widget> rowChildren = [];
    for (int i = 0; i < infoItems.length; i++) {
      rowChildren.add(infoItems[i]);
      if (i < infoItems.length - 1) {
        rowChildren.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(children: rowChildren);
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Gradient colors for connection types
  List<Color> _getConnectionTypeGradient(int index) {
    final gradients = [
      [const Color(0xFFEC4899), const Color(0xFFF472B6)], // Pink
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)], // Purple
      [const Color(0xFF6366F1), const Color(0xFF818CF8)], // Indigo
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)], // Cyan
      [const Color(0xFFF97316), const Color(0xFFFB923C)], // Orange
    ];
    return gradients[index % gradients.length];
  }

  // Gradient colors for activities
  List<Color> _getActivityGradient(int index) {
    final gradients = [
      [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)], // Violet
      [const Color(0xFFEC4899), const Color(0xFFF472B6)], // Pink
      [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)], // Sky
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)], // Amber
      [const Color(0xFF10B981), const Color(0xFF34D399)], // Emerald
    ];
    return gradients[index % gradients.length];
  }

  // Gradient colors for interests
  List<Color> _getInterestGradient(int index) {
    final gradients = [
      [const Color(0xFF10B981), const Color(0xFF34D399)], // Emerald
      [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)], // Sky
      [const Color(0xFFF97316), const Color(0xFFFB923C)], // Orange
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)], // Purple
      [const Color(0xFFEAB308), const Color(0xFFFACC15)], // Yellow
      [const Color(0xFFEF4444), const Color(0xFFF87171)], // Red
    ];
    return gradients[index % gradients.length];
  }
}

// Custom painter for shimmer effect
class ShimmerPainter extends CustomPainter {
  final double progress;

  ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.03),
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            transform: const GradientRotation(math.pi / 4),
          ).createShader(
            Rect.fromLTWH(
              -size.width + (size.width * 3 * progress),
              0,
              size.width,
              size.height,
            ),
          );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
