import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import '../../screens/profile/profile_view_screen.dart';
import '../../services/voice_assistant_service.dart';
import '../../widgets/voice_orb.dart';
import '../../widgets/audio_visualizer.dart';

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
        return 'Thinking...';
      case VoiceAssistantState.speaking:
        return 'Speaking...';
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
              height: 40,
              barCount: 30,
            ),

            const SizedBox(height: 8),

            GestureDetector(
              onTap: _onOrbTap,
              child: VoiceOrb(
                state: _mapToOrbState(_service.state),
                size: 120,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _statusText,
              style: TextStyle(
                color: _service.errorHint.isNotEmpty
                    ? const Color(0xFFFF9800)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 10),
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

          // Result cards
          if (message.results != null && message.results!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.results!.length,
                  itemBuilder: (context, index) {
                    return _buildResultCard(message.results![index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onResultCardTap(Map<String, dynamic> post) async {
    final userId = post['userId'] as String?;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
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

  Widget _buildResultCard(Map<String, dynamic> post) {
    final userName = post['userName']?.toString() ?? '';
    final hasScore = post['score'] != null;

    return GestureDetector(
      onTap: () => _onResultCardTap(post),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title']?.toString() ?? 'Post',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (userName.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                userName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                post['description']?.toString() ?? '',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                if (hasScore)
                  Text(
                    '${((post['score'] as double) * 100).toStringAsFixed(0)}% match',
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
