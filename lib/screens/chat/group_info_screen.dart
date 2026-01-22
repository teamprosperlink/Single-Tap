import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../providers/other providers/app_providers.dart';
import 'group_media_gallery_screen.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupPhoto;
  final List<String> memberIds;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupPhoto,
    required this.memberIds,
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _muteNotifications = false;
  final Map<String, String> _memberNames = {};
  final Map<String, String?> _memberPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadMemberDetails();
    _loadNotificationSettings();
  }

  Future<void> _loadMemberDetails() async {
    try {
      for (final memberId in widget.memberIds) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _memberNames[memberId] = userData['name'] ?? 'Unknown';
            _memberPhotos[memberId] = userData['photoUrl'] ?? userData['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading member details: $e');
    }
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _muteNotifications = doc.data()?['isMuted'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _toggleMuteNotifications(bool value) async {
    setState(() {
      _muteNotifications = value;
    });

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .update({'isMuted': value});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Notifications muted' : 'Notifications unmuted',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating notification settings: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _muteNotifications = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openMediaGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMediaGalleryScreen(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
    );
  }

  void _showThemePicker() {
    Navigator.pop(context, 'theme');
  }

  void _searchInConversation() {
    Navigator.pop(context, 'search');
  }

  Future<void> _leaveGroup() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestore.collection('conversations').doc(widget.groupId).update({
          'participants': FieldValue.arrayRemove([currentUserId]),
          'participantNames.$currentUserId': FieldValue.delete(),
          'participantPhotos.$currentUserId': FieldValue.delete(),
        });

        if (mounted) {
          Navigator.pop(context); // Pop info screen
          Navigator.pop(context); // Pop chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have left the group'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error leaving group: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to leave group'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: const Text(
          'This will delete the conversation and all messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(widget.groupId)
            .collection('messages')
            .get();

        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        batch.delete(_firestore.collection('conversations').doc(widget.groupId));
        await batch.commit();

        if (mounted) {
          Navigator.pop(context); // Pop info screen
          Navigator.pop(context); // Pop chat screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting conversation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete conversation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image (same as Chat Info screen)
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
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Group Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Divider line
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.2),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Group Profile Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Column(
                                children: [
                                  // Group photo
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: PhotoUrlHelper.isValidUrl(widget.groupPhoto)
                                        ? CachedNetworkImageProvider(widget.groupPhoto!)
                                        : null,
                                    child: !PhotoUrlHelper.isValidUrl(widget.groupPhoto)
                                        ? const Icon(
                                            Icons.group,
                                            size: 60,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 20),

                                  // Group name
                                  Text(
                                    widget.groupName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),

                                  // Members count
                                  Text(
                                    '${widget.memberIds.length} members',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Mute Notifications
                        _buildOptionTile(
                          icon: Icons.notifications_off_rounded,
                          title: 'Mute Notifications',
                          trailing: Switch(
                            value: _muteNotifications,
                            onChanged: _toggleMuteNotifications,
                            activeTrackColor: AppColors.iosBlue.withValues(alpha: 0.5),
                            activeThumbColor: AppColors.iosBlue,
                          ),
                        ),

                        // Search in Conversation
                        _buildOptionTile(
                          icon: Icons.search_rounded,
                          title: 'Search in Conversation',
                          onTap: _searchInConversation,
                        ),

                        // Change Theme
                        _buildOptionTile(
                          icon: Icons.color_lens_rounded,
                          title: 'Change Theme',
                          onTap: _showThemePicker,
                        ),

                        // Media Gallery
                        _buildOptionTile(
                          icon: Icons.photo_library_rounded,
                          title: 'Media Gallery',
                          onTap: _openMediaGallery,
                        ),

                        const SizedBox(height: 20),

                        // Members section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Members',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...widget.memberIds.map((memberId) {
                                    final name = _memberNames[memberId] ?? 'Loading...';
                                    final photo = _memberPhotos[memberId];

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.grey[800],
                                        backgroundImage: PhotoUrlHelper.isValidUrl(photo)
                                            ? CachedNetworkImageProvider(photo!)
                                            : null,
                                        child: !PhotoUrlHelper.isValidUrl(photo)
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Leave Group
                        _buildOptionTile(
                          icon: Icons.exit_to_app_rounded,
                          title: 'Leave Group',
                          onTap: _leaveGroup,
                        ),

                        // Delete Conversation
                        _buildOptionTile(
                          icon: Icons.delete_rounded,
                          title: 'Delete Conversation',
                          onTap: _deleteConversation,
                        ),

                        const SizedBox(height: 40),
                      ],
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            leading: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing: trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      )
                    : null),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
