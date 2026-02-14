import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/profile/downloads_screen.dart';
import '../screens/profile/library_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/help_center_screen.dart';
import '../screens/profile/upgrade_plan_screen.dart';
import '../screens/profile/personalization_screen.dart';
import '../screens/home/profile_with_history_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart' show navigatorKey;
import '../screens/login/onboarding_screen.dart';
import 'floating_particles.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/home/product/my_orders_screen.dart';
import '../screens/home/main_navigation_screen.dart';

/// ChatGPT-style drawer widget for the app
class AppDrawer extends StatefulWidget {
  /// Global key to access AppDrawer state for refresh
  static final GlobalKey<AppDrawerState> globalKey =
      GlobalKey<AppDrawerState>();

  final Future<void> Function()? onNewChat;
  final Function(int)? onNavigate;
  final Function(String chatId)? onLoadChat;
  final Function(String projectId)? onNewChatInProject;

  const AppDrawer({
    super.key,
    this.onNewChat,
    this.onNavigate,
    this.onLoadChat,
    this.onNewChatInProject,
  });

  @override
  State<AppDrawer> createState() => AppDrawerState();
}

class AppDrawerState extends State<AppDrawer> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _recentChats = [];
  bool _showAllChats = false;
  bool _showProfileMenu = false;
  bool _showChatHistory = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentChats();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userProfile = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadRecentChats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Load from chat_history collection (saved home screen conversations)
      // Using simple query without orderBy to avoid composite index requirement
      final chatsSnapshot = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .get();

      debugPrint('Chat history loaded: ${chatsSnapshot.docs.length} documents');

      final chats = <Map<String, dynamic>>[];

      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        // Skip archived chats and project chats (shown in Library)
        if (data['isArchived'] == true) continue;
        if (data['projectId'] != null) continue;
        chats.add({
          'id': doc.id,
          'name': data['title'] ?? 'Chat',
          'lastMessage': '',
          'createdAt': data['createdAt'],
          'unreadCount': 0,
          'isPinned': data['isPinned'] ?? false,
        });
      }

      // Sort: pinned first, then by createdAt (newest first)
      chats.sort((a, b) {
        final aPinned = a['isPinned'] == true;
        final bPinned = b['isPinned'] == true;
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      // Keep only first 20
      final limitedChats = chats.take(20).toList();

      if (mounted) {
        setState(() => _recentChats = limitedChats);
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  /// Public method to refresh chat history list
  Future<void> refreshChatHistory() async {
    await _loadRecentChats();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final size = MediaQuery.of(context).size;

    final bottomNavHeight = MediaQuery.of(context).padding.bottom + 70;

    return Container(
      margin: EdgeInsets.only(bottom: bottomNavHeight),
      child: Drawer(
        width: size.width * 0.65,
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  'assets/logo/home_background.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey.shade900, Colors.black],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Blur overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating particles
              const Positioned.fill(child: FloatingParticles(particleCount: 8)),

              // Border overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Color(0xFF016CFF), width: 1.5),
                    ),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    // Header with profile and close button
                    _buildHeader(user),

                    const Divider(color: Colors.white12, height: 1),

                    const SizedBox(height: 8),

                    // Feature Cards - Single Column
                    _buildFeatureCard(
                      icon: Icons.edit_outlined,
                      label: 'New Chat',
                      color: Colors.blue,
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        // Save conversation first
                        await widget.onNewChat?.call();
                        // Refresh chat history
                        await _loadRecentChats();
                        // Then close drawer
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),

                    _buildFeatureCard(
                      icon: Icons.image_outlined,
                      label: 'Downloads',
                      color: Colors.purple,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        );
                      },
                    ),

                    _buildFeatureCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'My Orders',
                      color: Colors.teal,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyOrdersScreen(),
                          ),
                        ).then((_) {
                          MainNavigationScreen.scaffoldKey.currentState
                              ?.openEndDrawer();
                        });
                      },
                    ),

                    _buildFeatureCard(
                      icon: Icons.folder_outlined,
                      label: 'Library',
                      color: Colors.orange,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LibraryScreen(
                              onLoadChat: widget.onLoadChat,
                              onNewChatInProject: widget.onNewChatInProject,
                            ),
                          ),
                        );
                      },
                    ),

                    // Chat History expandable card
                    _buildExpandableFeatureCard(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat History',
                      color: Colors.green,
                      isExpanded: _showChatHistory,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showChatHistory = !_showChatHistory);
                      },
                    ),

                    // Chat list (shown when expanded)
                    if (_showChatHistory)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 2,
                            bottom: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _recentChats.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        'No chats yet',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 8,
                                    ),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    shrinkWrap: false,
                                    itemCount: _showAllChats
                                        ? _recentChats.length
                                        : (_recentChats.length > 10
                                              ? 11
                                              : _recentChats.length),
                                    itemBuilder: (context, index) {
                                      if (!_showAllChats &&
                                          index == 10 &&
                                          _recentChats.length > 10) {
                                        return _buildShowMoreButton();
                                      }
                                      return _buildChatItem(
                                        _recentChats[index],
                                      );
                                    },
                                  ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    // Bottom profile button
                    _buildProfileButton(user),
                  ],
                ),
              ),

              // Overlay to close popup when tapping outside
              if (_showProfileMenu)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showProfileMenu = false);
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // Profile menu popup
              if (_showProfileMenu)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 80,
                  child: _buildProfileMenuCard(user),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (_showProfileMenu) {
          setState(() => _showProfileMenu = false);
          return;
        }
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (_showProfileMenu) {
          setState(() => _showProfileMenu = false);
          return;
        }
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_right,
                color: isExpanded ? color : Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
      color: Colors.white.withValues(alpha: 0.15),
      child: Row(
        children: [
          // User avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: ClipOval(
              child: _userProfile?['photoUrl'] != null
                  ? CachedNetworkImage(
                      imageUrl: _userProfile!['photoUrl'],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAvatarPlaceholder(),
                      errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                    )
                  : _buildAvatarPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userProfile?['name'] ?? user?.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Close button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_showProfileMenu) {
                setState(() => _showProfileMenu = false);
                return;
              }
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final hasUnread = (chat['unreadCount'] as num) > 0;
    final chatId = chat['id'] as String?;
    final chatName = chat['name'] ?? 'Unknown';
    final isPinned = chat['isPinned'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            // Load this conversation (ChatGPT style)
            if (chatId != null) {
              widget.onLoadChat?.call(chatId);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.only(
              left: 12,
              top: 4,
              bottom: 4,
              right: 2,
            ),
            decoration: BoxDecoration(
              color: hasUnread
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.push_pin,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 12,
                    ),
                  ),
                Expanded(
                  child: Text(
                    chatName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUnread)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                // 3-dot menu button
                SizedBox(
                  width: 28,
                  height: 28,
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: const Color(0xFF2D2D2D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) =>
                        _handleChatMenuAction(value, chatId, chatName),
                    itemBuilder: (context) {
                      final isPinned = chat['isPinned'] == true;
                      return [
                        _buildPopupMenuItem(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          value: 'share',
                        ),
                        _buildPopupMenuItem(
                          icon: Icons.edit_outlined,
                          label: 'Rename',
                          value: 'rename',
                        ),
                        _buildPopupMenuItem(
                          icon: isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          label: isPinned ? 'Unpin chat' : 'Pin chat',
                          value: 'pin',
                        ),
                        _buildPopupMenuItem(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          value: 'archive',
                        ),
                        const PopupMenuDivider(),
                        _buildPopupMenuItem(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          value: 'delete',
                          isDestructive: true,
                        ),
                      ];
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // White divider line below each chat
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 0.5,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleChatMenuAction(
    String action,
    String? chatId,
    String chatName,
  ) async {
    if (chatId == null) return;

    switch (action) {
      case 'share':
        HapticFeedback.lightImpact();
        _shareChat(chatId, chatName);
        break;
      case 'rename':
        HapticFeedback.lightImpact();
        _showRenameDialog(chatId, chatName);
        break;
      case 'pin':
        HapticFeedback.lightImpact();
        _togglePinChat(chatId);
        break;
      case 'archive':
        HapticFeedback.lightImpact();
        _archiveChat(chatId, chatName);
        break;
      case 'delete':
        HapticFeedback.mediumImpact();
        _showDeleteConfirmation(chatId, chatName);
        break;
    }
  }

  Future<void> _shareChat(String chatId, String chatName) async {
    try {
      // Load chat messages
      final messagesSnapshot = await _firestore
          .collection('chat_history')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp')
          .limit(100)
          .get();

      if (messagesSnapshot.docs.isEmpty) {
        // If no messages subcollection, share just the title
        Share.share('Chat: $chatName\n\nShared from Supper');
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Chat: $chatName');
      buffer.writeln('---');

      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        final role = data['role'] ?? 'user';
        final content = data['content'] ?? data['text'] ?? '';
        if (content.toString().isNotEmpty) {
          buffer.writeln('${role == 'user' ? 'You' : 'AI'}: $content');
          buffer.writeln();
        }
      }

      buffer.writeln('---');
      buffer.writeln('Shared from Supper');

      Share.share(buffer.toString(), subject: chatName);
    } catch (e) {
      debugPrint('Error sharing chat: $e');
      // Fallback: share just the title
      Share.share('Chat: $chatName\n\nShared from Supper');
    }
  }

  Future<void> _togglePinChat(String chatId) async {
    try {
      // Find the chat in current list to check pin status
      final chatIndex = _recentChats.indexWhere((c) => c['id'] == chatId);
      final isPinned = chatIndex >= 0
          ? (_recentChats[chatIndex]['isPinned'] ?? false)
          : false;

      await _firestore.collection('chat_history').doc(chatId).update({
        'isPinned': !isPinned,
      });

      await _loadRecentChats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isPinned ? 'Chat pinned' : 'Chat unpinned'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> _archiveChat(String chatId, String chatName) async {
    try {
      await _firestore.collection('chat_history').doc(chatId).update({
        'isArchived': true,
      });

      await _loadRecentChats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$chatName" archived'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                await _firestore.collection('chat_history').doc(chatId).update({
                  'isArchived': false,
                });
                await _loadRecentChats();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error archiving chat: $e');
    }
  }

  void _showRenameDialog(String chatId, String currentName) {
    final controller = TextEditingController(text: currentName);
    final drawerContext = context;

    showDialog(
      context: drawerContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rename chat',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                await _firestore.collection('chat_history').doc(chatId).update({
                  'title': newName,
                });
                await _loadRecentChats();
              }
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String chatId, String chatName) {
    final drawerContext = context;

    showDialog(
      context: drawerContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete chat?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'This will delete "$chatName" permanently.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _firestore.collection('chat_history').doc(chatId).delete();
              await _loadRecentChats();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showAllChats = true);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.expand_more_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              'Show more',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileButton(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Colors.white.withValues(alpha: 0.15),
      child: Row(
        children: [
          // Avatar - opens profile page
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_showProfileMenu) {
                setState(() => _showProfileMenu = false);
                return;
              }
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileWithHistoryScreen(),
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.3),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: ClipOval(
                child: _userProfile?['photoUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: _userProfile!['photoUrl'],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildAvatarPlaceholder(),
                        errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                      )
                    : _buildAvatarPlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _userProfile?['name'] ?? user?.displayName ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Settings icon - opens popup menu
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showProfileMenu = !_showProfileMenu);
            },
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white54,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    final name = _userProfile?['name'] ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      color: Colors.purple.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuCard(User? user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),

          // Menu items
          _buildProfileMenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            showArrow: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileWithHistoryScreen(),
                ),
              );
            },
          ),

          _buildProfileMenuItem(
            icon: Icons.workspace_premium_outlined,
            label: 'Upgrade Plan',
            showArrow: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpgradePlanScreen()),
              );
            },
          ),

          _buildProfileMenuItem(
            icon: Icons.tune_rounded,
            label: 'Personalization',
            showArrow: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonalizationScreen(),
                ),
              );
            },
          ),

          _buildProfileMenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            showArrow: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          _buildProfileMenuItem(
            icon: Icons.help_outline_rounded,
            label: 'Help',
            showArrow: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
              );
            },
          ),

          _buildProfileMenuItem(
            icon: Icons.logout_rounded,
            label: 'Log out',
            isDestructive: true,
            onTap: () {
              setState(() => _showProfileMenu = false);
              Navigator.pop(context);
              // Sign out and force navigate to login screen
              FirebaseAuth.instance.signOut().then((_) {
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false,
                );
              });
              // Full cleanup in background
              AuthService().signOut().catchError((_) {});
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showArrow = false,
    bool isDestructive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.8)
                      : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red.withValues(alpha: 0.8)
                          : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        // White divider line (not for destructive/last items)
        if (!isDestructive)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 0.5,
            color: Colors.white.withValues(alpha: 0.15),
          ),
      ],
    );
  }
}
