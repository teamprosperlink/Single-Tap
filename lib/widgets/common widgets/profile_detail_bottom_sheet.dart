import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/extended_user_profile.dart';
class ProfileDetailBottomSheet extends StatelessWidget {
  final ExtendedUserProfile user;
  final String? connectionStatus; // 'connected', 'sent', 'received', or null
  final VoidCallback? onConnect;
  final VoidCallback onMessage;

  const ProfileDetailBottomSheet({
    super.key,
    required this.user,
    this.connectionStatus,
    this.onConnect,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? Colors.white70 : Colors.black54;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar
          CircleAvatar(
            radius: 44,
            backgroundColor:
                const Color(0xFF3B82F6).withValues(alpha: 0.15),
            backgroundImage: user.photoUrl != null
                ? CachedNetworkImageProvider(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Text(
                    user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),

          // Name + online indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.isOnline) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Location
          if (user.city != null || user.location != null)
            Text(
              user.city ?? user.location ?? '',
              style: TextStyle(color: subtitleColor, fontSize: 14),
            ),

          // Connection status badge
          if (connectionStatus != null) ...[
            const SizedBox(height: 10),
            _buildStatusBadge(connectionStatus!, isDark),
          ],

          // About
          if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                user.aboutMe!,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Interests
          if (user.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: user.interests.take(6).map((interest) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Connect button
                if (connectionStatus != 'connected') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onConnect,
                      icon: Icon(
                        connectionStatus == 'sent'
                            ? Icons.hourglass_top
                            : Icons.person_add_outlined,
                        size: 18,
                      ),
                      label: Text(
                        connectionStatus == 'sent'
                            ? 'Request Sent'
                            : connectionStatus == 'received'
                                ? 'Accept'
                                : 'Connect',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: onConnect != null
                            ? const Color(0xFF22C55E)
                            : (isDark ? Colors.white12 : Colors.black12),
                        foregroundColor: onConnect != null
                            ? Colors.white
                            : subtitleColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Message button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
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

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final Color color;
    final String label;
    final IconData icon;

    switch (status) {
      case 'connected':
        color = const Color(0xFF22C55E);
        label = 'Connected';
        icon = Icons.check_circle_outline;
      case 'sent':
        color = const Color(0xFFF59E0B);
        label = 'Request Sent';
        icon = Icons.hourglass_top;
      case 'received':
        color = const Color(0xFF3B82F6);
        label = 'Request Received';
        icon = Icons.person_add_outlined;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
