import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:timeago/timeago.dart' as timeago;
import '../../models/conversation_model.dart';
import '../../models/user_profile.dart';
import '../../screens/chat/enhanced_chat_screen.dart';
import '../../res/utils/app_optimizer.dart';

/// Optimized conversation list with better performance
class OptimizedConversationList extends StatefulWidget {
  final bool isDarkMode;
  final String searchQuery;

  const OptimizedConversationList({
    super.key,
    required this.isDarkMode,
    this.searchQuery = '',
  });

  @override
  State<OptimizedConversationList> createState() =>
      _OptimizedConversationListState();
}

class _OptimizedConversationListState extends State<OptimizedConversationList>
    with AutomaticKeepAliveClientMixin, MemoryAwareMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Pagination
  static const int _pageSize = 20;
  final List<ConversationModel> _conversations = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreConversations();
    }
  }

  Future<void> _loadConversations() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      Query query = _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      final conversations = await _processConversations(snapshot.docs);

      if (mounted) {
        setState(() {
          _conversations.clear();
          _conversations.addAll(conversations);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreConversations() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      Query query = _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      final conversations = await _processConversations(snapshot.docs);

      if (mounted) {
        setState(() {
          _conversations.addAll(conversations);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more conversations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<ConversationModel>> _processConversations(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final conversations = <ConversationModel>[];
    final userId = _auth.currentUser?.uid;
    if (userId == null) return conversations;

    for (var doc in docs) {
      try {
        final conversation = ConversationModel.fromFirestore(doc);

        // Get other user's details
        final otherUserId = conversation.participantIds.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          // Use cached user data if available
          final otherUserDoc = await _firestore
              .collection('users')
              .doc(otherUserId)
              .get();

          if (otherUserDoc.exists) {
            final updatedConversation = conversation.copyWith(
              otherUser: UserProfile.fromMap(otherUserDoc.data()!, otherUserId),
            );
            conversations.add(updatedConversation);
          }
        }
      } catch (e) {
        debugPrint('Error processing conversation: $e');
      }
    }

    return conversations;
  }

  List<ConversationModel> get _filteredConversations {
    if (widget.searchQuery.isEmpty) {
      return _conversations;
    }

    final query = widget.searchQuery.toLowerCase();
    return _conversations.where((conv) {
      final userName = conv.otherUser?.name.toLowerCase() ?? '';
      final lastMessage = conv.lastMessage?.toLowerCase() ?? '';
      return userName.contains(query) || lastMessage.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final conversations = _filteredConversations;

    if (conversations.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: conversations.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == conversations.length) {
            return _buildLoadingIndicator();
          }

          final conversation = conversations[index];
          return _ConversationTile(
            conversation: conversation,
            isDarkMode: widget.isDarkMode,
            onTap: () => _openChat(conversation),
            onLongPress: () => _showConversationOptions(conversation),
          );
        },
        // Performance optimizations
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        cacheExtent: 100,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to begin messaging',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  void _openChat(ConversationModel conversation) {
    if (conversation.otherUser == null) return;

    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EnhancedChatScreen(otherUser: conversation.otherUser!),
      ),
    );
  }

  void _showConversationOptions(ConversationModel conversation) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ConversationOptionsSheet(
        conversation: conversation,
        isDarkMode: widget.isDarkMode,
        onDelete: () => _deleteConversation(conversation),
        onMute: () => _muteConversation(conversation),
        onBlock: () => _blockUser(conversation),
      ),
    );
  }

  Future<void> _deleteConversation(ConversationModel conversation) async {
    // Implementation
  }

  Future<void> _muteConversation(ConversationModel conversation) async {
    // Implementation
  }

  Future<void> _blockUser(ConversationModel conversation) async {
    // Implementation
  }
}

/// Optimized conversation tile
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isDarkMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherUser;
    if (otherUser == null) return const SizedBox.shrink();

    final unreadCount = // ignore: dead_null_aware_expression
        conversation.unreadCount[FirebaseAuth.instance.currentUser?.uid] ?? 0;
    final isOnline =
        otherUser.isOnline ?? false; // ignore: dead_null_aware_expression

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOnline ? Colors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: otherUser.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: otherUser.photoUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 112,
                              memCacheHeight: 112,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[300]),
                              errorWidget: (context, url, error) =>
                                  _buildDefaultAvatar(otherUser),
                            )
                          : _buildDefaultAvatar(otherUser),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? Colors.black : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            otherUser.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageTime != null)
                          Text(
                            _formatTime(conversation.lastMessageTime!),
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? Theme.of(context).primaryColor
                                  : (isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessage ?? 'Start a conversation',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildDefaultAvatar(UserProfile user) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return timeago.format(dateTime, locale: 'en_short');
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return timeago.format(dateTime, locale: 'en_short');
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

/// Conversation options sheet
class _ConversationOptionsSheet extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDarkMode;
  final VoidCallback onDelete;
  final VoidCallback onMute;
  final VoidCallback onBlock;

  const _ConversationOptionsSheet({
    required this.conversation,
    required this.isDarkMode,
    required this.onDelete,
    required this.onMute,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.volume_off),
            title: const Text('Mute notifications'),
            onTap: () {
              Navigator.pop(context);
              onMute();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete conversation'),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block user'),
            onTap: () {
              Navigator.pop(context);
              onBlock();
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
