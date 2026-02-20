import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/chat/enhanced_chat_screen.dart';
import '../../screens/profile/profile_view_screen.dart';
// REMOVED: Call feature imports (feature deleted)
// import '../services/simple_call_service.dart';
import '../../models/user_profile.dart';
import '../../res/config/app_text_styles.dart';
// import '../models/call_model.dart';

class MatchCardWithActions extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback? onTap;

  const MatchCardWithActions({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isDark ? 8 : 4,
      shadowColor: theme.primaryColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap ?? () => _viewProfile(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      theme.cardColor,
                      theme.cardColor.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Row
              Row(
                children: [
                  // Avatar
                  Hero(
                    tag: 'avatar_${match['userId']}',
                    child: _buildAvatar(match),
                  ),
                  const SizedBox(width: 12),

                  // Name and Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match['userName'] ?? 'User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (match['location'] != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                match['location'],
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Match score badge
                  if (match['matchScore'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getScoreColor(
                          (match['matchScore'] as num).toDouble(),
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getScoreColor(
                            (match['matchScore'] as num).toDouble(),
                          ).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${((match['matchScore'] as num).toDouble() * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(
                            (match['matchScore'] as num).toDouble(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Intent/Description
              if (match['text'] != null || match['intent'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    match['text'] ?? match['intent'] ?? '',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Action Buttons Row
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    // Chat Button
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        color: theme.primaryColor,
                        onTap: () => _startChat(context),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // View Profile Button
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        color: Colors.orange,
                        onTap: () => _viewProfile(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> match) {
    final profile = match['userProfile'] as Map<String, dynamic>?;
    final photoUrl =
        match['userProfile']?['photoUrl'] ??
        profile?['photoURL'] ??
        profile?['profileImageUrl'];
    final name = (match['userName'] as String? ?? 'U').trim();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 28,
      backgroundImage: (photoUrl != null && photoUrl.toString().startsWith('http'))
          ? CachedNetworkImageProvider(photoUrl.toString())
          : null,
      child: (photoUrl == null || !photoUrl.toString().startsWith('http'))
          ? Text(initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
          : null,
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.9) return Colors.green;
    if (score >= 0.8) return Colors.teal;
    if (score >= 0.7) return Colors.orange;
    return Colors.grey;
  }

  Future<void> _startChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get receiver's full profile
    final receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(match['userId'])
        .get();

    if (!receiverDoc.exists) return;

    final receiver = UserProfile.fromFirestore(receiverDoc);

    // Navigate to chat
    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(otherUser: receiver),
      ),
    );
  }

  Future<void> _viewProfile(BuildContext context) async {
    // Get full user profile
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(match['userId'])
        .get();

    if (!userDoc.exists) return;

    final profile = UserProfile.fromFirestore(userDoc);

    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(userProfile: profile),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
