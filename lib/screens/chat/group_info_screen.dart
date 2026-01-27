import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../providers/other providers/app_providers.dart';
import '../../models/user_profile.dart';
import 'group_media_gallery_screen.dart';
import 'enhanced_chat_screen.dart';

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
  late List<String> _memberIds; // Dynamic member list

  @override
  void initState() {
    super.initState();
    _memberIds = List.from(widget.memberIds); // Initialize from widget
    _loadMemberDetails();
    _loadNotificationSettings();
  }

  Future<void> _loadMemberDetails() async {
    try {
      for (final memberId in _memberIds) {
        final userDoc = await _firestore
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _memberNames[memberId] = userData['name'] ?? 'Unknown';
            _memberPhotos[memberId] =
                userData['photoUrl'] ?? userData['profileImageUrl'];
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
      await _firestore.collection('conversations').doc(widget.groupId).update({
        'isMuted': value,
      });

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

  Future<void> _showAddMembersDialog() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    // Load all users (excluding current group members)
    final usersSnapshot = await _firestore.collection('users').get();
    final availableUsers = usersSnapshot.docs
        .where((doc) => !_memberIds.contains(doc.id) && doc.id != currentUserId)
        .map(
          (doc) => {
            'uid': doc.id,
            'name': doc.data()['name'] ?? 'Unknown',
            'photoUrl': doc.data()['photoUrl'] ?? doc.data()['profileImageUrl'],
          },
        )
        .toList();

    if (!mounted) return;

    if (availableUsers.isEmpty) {
      return;
    }

    // Show dialog to select users
    final selectedUsers = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _AddMembersDialog(
        availableUsers: availableUsers,
        groupName: widget.groupName,
      ),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty && mounted) {
      await _addMembersToGroup(selectedUsers);
    }
  }

  Future<void> _addMembersToGroup(List<Map<String, dynamic>> users) async {
    try {
      final userIds = users.map((u) => u['uid'] as String).toList();
      final updatedMemberIds = [..._memberIds, ...userIds];

      // Update group members in Firestore
      await _firestore.collection('conversations').doc(widget.groupId).update({
        'participants': updatedMemberIds,
      });

      // Update local state to show new members immediately
      setState(() {
        _memberIds = updatedMemberIds;
      });

      // Add system message for each new member
      for (final user in users) {
        await _firestore
            .collection('conversations')
            .doc(widget.groupId)
            .collection('messages')
            .add({
              'text': '${user['name']} was added to the group',
              'senderId': ref.read(currentUserIdProvider),
              'timestamp': FieldValue.serverTimestamp(),
              'isSystemMessage': true,
              'readBy': [],
            });
      }

      if (mounted) {
        // Refresh member details
        _loadMemberDetails();
      }
    } catch (e) {
      debugPrint('Error adding members: $e');
    }
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
        await _firestore.collection('conversations').doc(widget.groupId).update(
          {
            'participants': FieldValue.arrayRemove([currentUserId]),
            'participantNames.$currentUserId': FieldValue.delete(),
            'participantPhotos.$currentUserId': FieldValue.delete(),
          },
        );

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
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Clear Chat?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Message
                    Text(
                      'This will clear all messages from this chat for you. Other members will still see all messages.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final currentUserId = ref.read(currentUserIdProvider);
        if (currentUserId == null) return;

        // Get all messages in the conversation
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(widget.groupId)
            .collection('messages')
            .get();

        if (messagesSnapshot.docs.isEmpty) {
          // No messages to clear - just close info screen
          if (mounted) {
            Navigator.pop(context); // Pop info screen only
          }
          return;
        }

        // Mark messages as deleted for current user only (not actually delete them)
        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          // Use set with merge to avoid errors if field doesn't exist
          batch.set(doc.reference, {
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          }, SetOptions(merge: true));
        }

        // Don't delete the conversation - just update last seen for current user
        // Other users will still see the group and all messages
        await batch.commit();

        if (mounted) {
          Navigator.pop(context); // Pop info screen only
          // User stays on chat screen - can manually press back when they want
        }
      } catch (e) {
        debugPrint('Error clearing chat: $e');
        // On error, just close info screen
        if (mounted) {
          Navigator.pop(context); // Pop info screen only
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
                              filter: ui.ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
                              child: Column(
                                children: [
                                  // Group photo
                                  CircleAvatar(
                                    radius: 45,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(
                                          widget.groupPhoto,
                                        )
                                        ? CachedNetworkImageProvider(
                                            widget.groupPhoto!,
                                          )
                                        : null,
                                    child:
                                        !PhotoUrlHelper.isValidUrl(
                                          widget.groupPhoto,
                                        )
                                        ? const Icon(
                                            Icons.group,
                                            size: 45,
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
                                    '${_memberIds.length} members',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Add Members button
                                  ElevatedButton.icon(
                                    onPressed: _showAddMembersDialog,
                                    icon: const Icon(
                                      Icons.person_add_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Add Members',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.iosBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
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
                            activeTrackColor: AppColors.iosBlue.withValues(
                              alpha: 0.5,
                            ),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                              filter: ui.ImageFilter.blur(
                                sigmaX: 10,
                                sigmaY: 10,
                              ),
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
                                  const SizedBox(height: 8),
                                  Divider(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                  const SizedBox(height: 8),
                                  ..._memberIds.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final memberId = entry.value;
                                    final isLastItem =
                                        index == _memberIds.length - 1;
                                    final currentUserId = ref.read(
                                      currentUserIdProvider,
                                    );
                                    final isCurrentUser =
                                        memberId == currentUserId;
                                    final name =
                                        _memberNames[memberId] ?? 'Loading...';
                                    final photo = _memberPhotos[memberId];

                                    return Column(
                                      children: [
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.grey[800],
                                            backgroundImage:
                                                PhotoUrlHelper.isValidUrl(photo)
                                                ? CachedNetworkImageProvider(
                                                    photo!,
                                                  )
                                                : null,
                                            child:
                                                !PhotoUrlHelper.isValidUrl(
                                                  photo,
                                                )
                                                ? Text(
                                                    name.isNotEmpty
                                                        ? name[0].toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          title: Text(
                                            isCurrentUser
                                                ? '$name (You)'
                                                : name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          trailing: !isCurrentUser
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.message_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                  onPressed: () async {
                                                    // Create UserProfile for the member
                                                    final userProfile = UserProfile(
                                                      uid: memberId,
                                                      name: name,
                                                      email:
                                                          '', // Email not needed for chat
                                                      profileImageUrl: photo,
                                                      createdAt: DateTime.now(),
                                                      lastSeen: DateTime.now(),
                                                    );

                                                    // Navigate to 1-to-1 chat with this user
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            EnhancedChatScreen(
                                                              otherUser:
                                                                  userProfile,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : null,
                                        ),
                                        // Only show divider if not the last item
                                        if (!isLastItem)
                                          Divider(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                            height: 1,
                                            thickness: 0.5,
                                          ),
                                      ],
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
            leading: Icon(icon, color: Colors.white.withValues(alpha: 0.8)),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            trailing:
                trailing ??
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

// Dialog for adding members to group
class _AddMembersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final String groupName;

  const _AddMembersDialog({
    required this.availableUsers,
    required this.groupName,
  });

  @override
  State<_AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<_AddMembersDialog> {
  final Set<Map<String, dynamic>> _selectedUsers = {};
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.availableUsers;
    return widget.availableUsers.where((user) {
      final name = (user['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSelection(Map<String, dynamic> user) {
    setState(() {
      final existingUser = _selectedUsers
          .where((u) => u['uid'] == user['uid'])
          .firstOrNull;
      if (existingUser != null) {
        _selectedUsers.remove(existingUser);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  bool _isSelected(String uid) {
    return _selectedUsers.any((u) => u['uid'] == uid);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 750, maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Members',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // Divider line below header
                  Divider(
                    color: Colors.white.withValues(alpha: 0.3),
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 10),

                  // Search bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Selected users count
                  if (_selectedUsers.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.iosBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedUsers.length} user(s) selected',
                        style: const TextStyle(
                          color: AppColors.iosBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // const SizedBox(height: 12),

                  // Users list
                  Expanded(
                    child: _filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No users found',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              final isSelected = _isSelected(user['uid']);
                              final isLastItem =
                                  index == _filteredUsers.length - 1;

                              return Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.grey[800],
                                        backgroundImage:
                                            PhotoUrlHelper.isValidUrl(
                                              user['photoUrl'],
                                            )
                                            ? CachedNetworkImageProvider(
                                                user['photoUrl']!,
                                              )
                                            : null,
                                        child:
                                            !PhotoUrlHelper.isValidUrl(
                                              user['photoUrl'],
                                            )
                                            ? Text(
                                                user['name'][0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    title: Text(
                                      user['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: AppColors.iosBlue,
                                          )
                                        : Icon(
                                            Icons.circle_outlined,
                                            color: Colors.grey[600],
                                          ),
                                    onTap: () => _toggleSelection(user),
                                  ),
                                  // Add divider between items (except last)
                                  if (!isLastItem)
                                    Divider(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      height: 1,
                                      thickness: 0.5,
                                      indent: 60,
                                      endIndent: 8,
                                    ),
                                ],
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 8),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedUsers.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  _selectedUsers.toList(),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.iosBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            disabledBackgroundColor: Colors.grey[800],
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
