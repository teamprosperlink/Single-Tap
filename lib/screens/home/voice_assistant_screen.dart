import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import '../../screens/chat/enhanced_chat_screen.dart';
import '../../screens/profile/profile_view_screen.dart';
import '../../services/firebase_provider.dart';
import '../../services/voice_assistant_service.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../widgets/voice_orb.dart';
import '../../widgets/audio_visualizer.dart';
import '../chat/conversations_screen.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late VoiceAssistantService _service;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _service = VoiceAssistantService();
    _service.onNavigate = _handleNavigation;
    _service.addListener(_onServiceUpdate);
    _service.initialize();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _service.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  VoiceOrbState _mapToOrbState(VoiceAssistantState s) {
    switch (s) {
      case VoiceAssistantState.idle:
        return VoiceOrbState.idle;
      case VoiceAssistantState.listening:
        return VoiceOrbState.listening;
      case VoiceAssistantState.processing:
        return VoiceOrbState.processing;
      case VoiceAssistantState.speaking:
        return VoiceOrbState.speaking;
    }
  }

  String get _statusText {
    if (_service.errorHint.isNotEmpty) return _service.errorHint;
    switch (_service.state) {
      case VoiceAssistantState.idle:
        return 'Tap to speak';
      case VoiceAssistantState.listening:
        return 'Listening...';
      case VoiceAssistantState.processing:
        return _service.processingHint.isNotEmpty
            ? _service.processingHint
            : 'Thinking...';
      case VoiceAssistantState.speaking:
        return 'Tap orb to stop';
    }
  }

  void _handleNavigation(String screen) {
    if (!mounted) return;
    final s = screen.toLowerCase();
    if (s == 'messages' || s == 'conversations') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConversationsScreen()),
      );
    } else if (s == 'profile' || s == 'my profile') {
      _navigateToOwnProfile();
    } else {
      // For discover / home / nearby / live — pop back to main nav
      Navigator.pop(context);
    }
  }

  Future<void> _navigateToOwnProfile() async {
    final uid = FirebaseProvider.currentUserId;
    if (uid == null || !mounted) return;
    try {
      final doc = await FirebaseProvider.firestore
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || !mounted) return;
      final profile = UserProfile.fromFirestore(doc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileViewScreen(userProfile: profile),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to own profile: $e');
    }
  }

  void _onOrbTap() {
    HapticFeedback.mediumImpact();
    _textFocusNode.unfocus();
    switch (_service.state) {
      case VoiceAssistantState.idle:
        _service.startListening();
        break;
      case VoiceAssistantState.listening:
        _service.stopListening();
        break;
      case VoiceAssistantState.speaking:
        _service.interruptSpeaking();
        break;
      case VoiceAssistantState.processing:
        break;
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _textFocusNode.unfocus();
    _service.sendTextMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 50;
    final isIdle = _service.state == VoiceAssistantState.idle;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Voice Assistant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              HapticFeedback.lightImpact();
              _service.clearConversation();
              _service.initialize();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversation transcript
          Expanded(
            child: _service.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _service.messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_service.messages[index]);
                    },
                  ),
          ),

          // Partial transcript
          if (_service.partialTranscript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                _service.partialTranscript,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Audio visualizer, orb, status - hidden when keyboard is open
          if (!keyboardOpen) ...[
            AudioVisualizer(
              isActive: _service.state == VoiceAssistantState.listening ||
                  _service.state == VoiceAssistantState.speaking,
              height: 32,
              barCount: 40,
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: _onOrbTap,
              child: VoiceOrb(
                state: _mapToOrbState(_service.state),
                size: 140,
              ),
            ),

            const SizedBox(height: 12),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: _service.errorHint.isNotEmpty
                    ? const Color(0xFFFF9800)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
              child: Text(_statusText),
            ),

            const SizedBox(height: 14),
          ],

          // Text input fallback
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomPadding + 12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _textFocusNode,
                          enabled: isIdle,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Type your question...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendTextMessage(),
                        ),
                      ),
                      GestureDetector(
                        onTap: isIdle ? _sendTextMessage : null,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isIdle
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFF06B6D4)
                                    ],
                                  )
                                : null,
                            color: isIdle ? null : Colors.grey[800],
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Your AI Voice Assistant',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the orb and ask me anything.\nOr type your question below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(VoiceMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          // Result cards (vertical, matching home screen layout)
          if (message.results != null && message.results!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: message.results!
                    .map((match) => _buildResultCard(match))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openProfile(String userId) async {
    try {
      final doc = await FirebaseProvider.firestore
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists || !mounted) return;

      final profile = UserProfile.fromFirestore(doc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileViewScreen(userProfile: profile),
        ),
      );
    } catch (e) {
      debugPrint('Error opening profile: $e');
    }
  }

  Future<void> _openOrCreateConversation(String targetUserId) async {
    final currentUid = FirebaseProvider.currentUserId;
    if (currentUid == null || !mounted) return;

    try {
      // Check for existing conversation
      final snap = await FirebaseProvider.firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUid)
          .limit(50)
          .get();

      String? existingChatId;
      for (final doc in snap.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(targetUserId)) {
          existingChatId = doc.id;
          break;
        }
      }

      // Create new conversation if none exists
      existingChatId ??= (await FirebaseProvider.firestore
              .collection('conversations')
              .add({
        'participants': [currentUid, targetUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      }))
          .id;

      if (!mounted) return;

      // Fetch target user profile for EnhancedChatScreen
      final userDoc = await FirebaseProvider.firestore
          .collection('users')
          .doc(targetUserId)
          .get();
      if (!userDoc.exists || !mounted) return;

      final profile = UserProfile.fromFirestore(userDoc);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedChatScreen(
            otherUser: profile,
            chatId: existingChatId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening conversation: $e');
    }
  }

  /// Match card identical to home screen's _buildMatchCard
  Widget _buildResultCard(Map<String, dynamic> match) {
    final userProfile =
        match['userProfile'] as Map<String, dynamic>? ?? {};

    // Handle both key names: 'matchScore' (from processIntentAndMatch)
    // and 'score' (from findMatchesForMe, getMatches, searchNearby)
    final rawScore = match['matchScore'] ?? match['score'] ?? 0.0;
    final matchScore =
        (rawScore is double ? rawScore : (rawScore as num).toDouble()) * 100;

    final userName =
        (match['userName'] as String?)?.isNotEmpty == true
            ? match['userName'] as String
            : (userProfile['name'] as String?)?.isNotEmpty == true
                ? userProfile['name'] as String
                : userProfile['displayName'] as String? ??
                    userProfile['phone'] as String? ??
                    'Unknown User';
    final userId = match['userId'] as String?;

    final photoUrl = (userProfile['photoUrl'] ??
            userProfile['photoURL'] ??
            userProfile['profileImageUrl'] ??
            match['userPhoto'] ??
            '')
        .toString();

    final distanceKm = match['distanceKm'] as double?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (userId == null) return;
          HapticFeedback.lightImpact();
          if (userProfile.isNotEmpty) {
            final otherUser = UserProfile.fromMap(userProfile, userId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnhancedChatScreen(otherUser: otherUser),
              ),
            );
          } else {
            _openOrCreateConversation(userId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + badge pills
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl:
                        photoUrl.isNotEmpty ? photoUrl : null,
                    radius: 24,
                    fallbackText: userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // Name badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Match % badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${matchScore.toStringAsFixed(0)}% match',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // City badge
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile['city'].toString(),
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Distance badge
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Title / description box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['title'] ??
                          match['description'] ??
                          'Looking for match',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null &&
                        match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Action buttons
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (userId == null) return;
                        HapticFeedback.lightImpact();
                        if (userProfile.isNotEmpty) {
                          final otherUser =
                              UserProfile.fromMap(userProfile, userId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EnhancedChatScreen(otherUser: otherUser),
                            ),
                          );
                        } else {
                          _openOrCreateConversation(userId);
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Chat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (userId == null) return;
                        HapticFeedback.lightImpact();
                        _openProfile(userId);
                      },
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
