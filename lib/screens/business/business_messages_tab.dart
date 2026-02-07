import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:ui';

import '../../models/business_model.dart';
import '../../models/conversation_model.dart';
import '../../models/user_profile.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/config/app_assets.dart';
import '../../res/config/app_colors.dart';
import '../../services/chat_services/conversation_service.dart';
import '../../widgets/chat_common.dart';
import '../chat/enhanced_chat_screen.dart';

/// Business Messages Tab - Shows all messages for a business profile (for bottom nav)
class BusinessMessagesTab extends StatefulWidget {
  final BusinessModel business;

  const BusinessMessagesTab({
    super.key,
    required this.business,
  });

  @override
  State<BusinessMessagesTab> createState() => _BusinessMessagesTabState();
}

class _BusinessMessagesTabState extends State<BusinessMessagesTab> {
  final ConversationService _conversationService = ConversationService();
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            AppAssets.homeBackgroundImage,
            fit: BoxFit.cover,
          ),
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(color: AppColors.darkOverlay()),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Divider
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),

              // Search bar
              _buildSearchBar(),

              // Conversations list
              Expanded(
                child: _buildConversationsList(),
              ),

              // Bottom padding for nav bar
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Business logo
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: widget.business.logo != null
                  ? CachedNetworkImage(
                      imageUrl: widget.business.logo!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _buildLogoPlaceholder(),
                      errorWidget: (_, _, _) => _buildLogoPlaceholder(),
                    )
                  : _buildLogoPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.business.businessName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Business badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D67D).withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  color: Color(0xFF00D67D),
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'Business',
                  style: TextStyle(
                    color: Color(0xFF00D67D),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00D67D),
      ),
      child: Center(
        child: Text(
          widget.business.businessName.isNotEmpty
              ? widget.business.businessName[0].toUpperCase()
              : 'B',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name or @username',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    // If searching, show search results (conversations + users)
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    // Default: show existing conversations only
    return StreamBuilder<List<ConversationModel>>(
      stream: _conversationService.getBusinessConversations(widget.business.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D67D),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error loading messages',
            subtitle: 'Please try again later',
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            subtitle: 'Messages from customers will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _buildConversationTile(snapshot.data![index]);
          },
        );
      },
    );
  }

  /// Build search results - shows existing conversations + users from search
  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchUsersAndConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error searching',
            subtitle: 'Please try again',
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off,
            title: 'No results found',
            subtitle: 'Try a different name or @username',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final item = results[index];
            if (item['type'] == 'conversation') {
              return _buildConversationTile(item['data'] as ConversationModel);
            } else {
              return _buildUserSearchResult(
                item['data'] as Map<String, dynamic>,
                item['userId'] as String,
              );
            }
          },
        );
      },
    );
  }

  /// Search for users and conversations matching the query
  Future<List<Map<String, dynamic>>> _searchUsersAndConversations() async {
    final results = <Map<String, dynamic>>[];
    final seenUserIds = <String>{};

    // Clean search query for username search
    final searchQueryClean = _searchQuery.startsWith('@')
        ? _searchQuery.substring(1)
        : _searchQuery;

    // First, search existing conversations
    try {
      final conversations = await _conversationService
          .getBusinessConversations(widget.business.id)
          .first;

      for (var conv in conversations) {
        final otherUserId = conv.getOtherParticipantId(widget.business.userId);
        if (otherUserId.isEmpty) continue;

        final name = (conv.participantNames[otherUserId] ?? '').toLowerCase();

        // Get username from cache or fetch
        String? username;
        if (_userCache.containsKey(otherUserId)) {
          username = _userCache[otherUserId]?['username'] as String?;
        } else {
          try {
            final userDoc = await _firestore.collection('users').doc(otherUserId).get();
            if (userDoc.exists) {
              _userCache[otherUserId] = userDoc.data()!;
              username = userDoc.data()?['username'] as String?;
            }
          } catch (_) {}
        }

        // Check if matches search
        if (name.contains(_searchQuery) ||
            (username != null && username.toLowerCase().contains(searchQueryClean))) {
          seenUserIds.add(otherUserId);
          results.add({
            'type': 'conversation',
            'data': conv,
            'userId': otherUserId,
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    }

    // Then, search ALL users by name
    try {
      var nameQuery = await _firestore
          .collection('users')
          .where('nameLower', isGreaterThanOrEqualTo: _searchQuery)
          .where('nameLower', isLessThan: '${_searchQuery}z')
          .limit(20)
          .get();

      // If no results, try with capitalized name
      if (nameQuery.docs.isEmpty) {
        final capitalizedQuery = _searchQuery.isNotEmpty
            ? _searchQuery[0].toUpperCase() + _searchQuery.substring(1)
            : _searchQuery;
        nameQuery = await _firestore
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: capitalizedQuery)
            .where('name', isLessThan: '${capitalizedQuery}z')
            .limit(20)
            .get();
      }

      for (var doc in nameQuery.docs) {
        if (doc.id != widget.business.userId && !seenUserIds.contains(doc.id)) {
          seenUserIds.add(doc.id);
          final userData = doc.data();
          _userCache[doc.id] = userData;
          results.add({
            'type': 'user',
            'data': userData,
            'userId': doc.id,
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching by name: $e');
    }

    // Search ALL users by username
    if (searchQueryClean.isNotEmpty) {
      try {
        final usernameQuery = await _firestore
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: searchQueryClean)
            .where('username', isLessThan: '${searchQueryClean}z')
            .limit(20)
            .get();

        for (var doc in usernameQuery.docs) {
          if (doc.id != widget.business.userId && !seenUserIds.contains(doc.id)) {
            seenUserIds.add(doc.id);
            final userData = doc.data();
            _userCache[doc.id] = userData;
            results.add({
              'type': 'user',
              'data': userData,
              'userId': doc.id,
            });
          }
        }
      } catch (e) {
        debugPrint('Error searching by username: $e');
      }
    }

    return results;
  }

  /// Build a user search result tile (for users not yet chatted with)
  Widget _buildUserSearchResult(Map<String, dynamic> userData, String userId) {
    final name = userData['name'] ?? 'Unknown';
    final username = userData['username'] as String?;
    final photoUrl = userData['photoUrl'] as String?;
    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(photoUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openChatWithUser(userData, userId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildUserAvatar(
                        photoUrl: fixedPhotoUrl,
                        initial: initial,
                        uniqueId: userId,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatDisplayName(name),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username != null && username.isNotEmpty
                                  ? '@$username'
                                  : 'Tap to message',
                              style: TextStyle(
                                fontSize: 13,
                                color: username != null && username.isNotEmpty
                                    ? const Color(0xFF00D67D)
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Open chat with a user from search results
  void _openChatWithUser(Map<String, dynamic> userData, String userId) {
    HapticFeedback.lightImpact();
    final userProfile = UserProfile.fromMap(userData, userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(
          otherUser: userProfile,
          isBusinessChat: true,
          business: widget.business,
        ),
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    final otherUserId =
        conversation.getOtherParticipantId(widget.business.userId);
    final displayName = conversation.participantNames[otherUserId] ?? 'Customer';
    final displayPhoto = conversation.participantPhotos[otherUserId];
    final unreadCount = conversation.getUnreadCount(widget.business.userId);
    final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(displayPhoto);
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openConversation(conversation, otherUserId),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Avatar
                      _buildUserAvatar(
                        photoUrl: fixedPhotoUrl,
                        initial: initial,
                        uniqueId: otherUserId,
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
                                    formatDisplayName(displayName),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (conversation.lastMessageTime != null)
                                  Text(
                                    timeago.format(conversation.lastMessageTime!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: unreadCount > 0
                                          ? const Color(0xFF00D67D)
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conversation.lastMessage ??
                                        'Start a conversation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D67D),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount > 99
                                          ? '99+'
                                          : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar({
    required String? photoUrl,
    required String initial,
    required String uniqueId,
  }) {
    const List<Color> avatarColors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFF22C55E),
      Color(0xFF14B8A6),
      Color(0xFF06B6D4),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
    ];

    int hash = 0;
    for (int i = 0; i < uniqueId.length; i++) {
      hash = uniqueId.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final avatarColor = avatarColors[hash.abs() % avatarColors.length];

    Widget buildFallback() {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: avatarColor,
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (photoUrl == null || photoUrl.isEmpty) {
      return buildFallback();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (_, _) => buildFallback(),
        errorWidget: (_, _, _) => buildFallback(),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _openConversation(
    ConversationModel conversation,
    String otherUserId,
  ) async {
    HapticFeedback.lightImpact();

    // Create UserProfile from conversation data
    final otherUser = UserProfile(
      uid: otherUserId,
      name: conversation.participantNames[otherUserId] ?? 'Customer',
      email: '',
      profileImageUrl: conversation.participantPhotos[otherUserId],
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(
          otherUser: otherUser,
          chatId: conversation.id,
          isBusinessChat: true,
          business: widget.business,
        ),
      ),
    );
  }
}
