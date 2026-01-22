import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/config/app_colors.dart';

/// WhatsApp-style Group Audio Call Screen
/// Supports multiple participants with audio-only conference call
class GroupAudioCallScreen extends StatefulWidget {
  final String callId;
  final String userId;
  final String userName;
  final List<Map<String, dynamic>> participants; // List of {userId, name, photoUrl}

  const GroupAudioCallScreen({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
    required this.participants,
  });

  @override
  State<GroupAudioCallScreen> createState() => _GroupAudioCallScreenState();
}

class _GroupAudioCallScreenState extends State<GroupAudioCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _callTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isEndingCall = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Track participant info: participantId -> {name, photoUrl, isActive}
  final Map<String, Map<String, dynamic>> _participantInfo = {};
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🎙️ GroupAudioCallScreen: initState - callId=${widget.callId}');

    // Initialize pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // CRITICAL FIX: Deduplicate participants by userId before storing
    // This prevents duplicate participant cards in the UI
    final seenUserIds = <String>{};
    int duplicateCount = 0;

    for (var participant in widget.participants) {
      final userId = participant['userId'] as String;

      if (!seenUserIds.contains(userId)) {
        // First time seeing this userId - add to map
        seenUserIds.add(userId);
        _participantInfo[userId] = {
          'name': participant['name'] ?? 'Unknown',
          'photoUrl': participant['photoUrl'],
          'isActive': userId == widget.userId, // Current user is active
        };
      } else {
        // Duplicate userId found - skip it
        duplicateCount++;
        debugPrint('⚠️ Skipping duplicate participant: $userId (${participant['name']})');
      }
    }

    if (duplicateCount > 0) {
      debugPrint('🔧 Removed $duplicateCount duplicate participants from ${widget.participants.length} total');
    }

    debugPrint('✅ Final unique participants: ${_participantInfo.keys.length}');

    _listenToParticipants();
    _startCallTimer();
    _updateCallStatus('active');
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _participantsSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _listenToParticipants() {
    _participantsSubscription = _firestore
        .collection('group_calls')
        .doc(widget.callId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] as String;

          if (_participantInfo.containsKey(userId)) {
            _participantInfo[userId]!['isActive'] = data['isActive'] == true;
          }
        }

        // Start timer only when at least one other person (not current user) becomes active
        final othersActive = _participantInfo.entries
            .where((entry) => entry.key != widget.userId && entry.value['isActive'] == true)
            .isNotEmpty;

        if (othersActive && _callDuration == 0) {
          // First person joined, start the timer
          debugPrint('✅ First participant joined, starting call timer');
        }
      });
    });
  }

  void _startCallTimer() {
    // Timer runs but only increments when at least one other person (not current user) is active
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check if anyone else (excluding current user) is active
        final othersActive = _participantInfo.entries
            .where((entry) => entry.key != widget.userId && entry.value['isActive'] == true)
            .isNotEmpty;

        if (othersActive) {
          setState(() => _callDuration++);
        }
      }
    });
  }

  Future<void> _updateCallStatus(String status) async {
    try {
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'status': status,
        if (status == 'ended') 'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating call status: $e');
    }
  }

  Future<void> _updateParticipantStatus(bool isActive) async {
    try {
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.userId)
          .update({'isActive': isActive});
    } catch (e) {
      debugPrint('❌ Error updating participant status: $e');
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    // TODO: Implement actual audio muting via WebRTC
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    // TODO: Implement actual speaker toggle via WebRTC
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      await _updateParticipantStatus(false);
      await _updateCallStatus('ended');
    } catch (e) {
      debugPrint('❌ Error ending call: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Count active participants excluding current user
    final activeParticipants = _participantInfo.entries
        .where((entry) => entry.key != widget.userId && entry.value['isActive'] == true)
        .map((entry) => entry.value)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            const SizedBox(height: 40),

            // Call duration
            Text(
              _formatDuration(_callDuration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // Call status
            Text(
              activeParticipants.isEmpty
                  ? 'Calling...'
                  : '${activeParticipants.length} ${activeParticipants.length == 1 ? 'person' : 'people'} joined',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // Participants grid
            _buildParticipantsGrid(activeParticipants),

            const Spacer(),

            // Controls
            _buildControls(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.group, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Group Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid(List<Map<String, dynamic>> activeParticipants) {
    // Show all participants EXCEPT the current user (caller should not see themselves)
    final allParticipants = _participantInfo.entries
        .where((entry) => entry.key != widget.userId) // Exclude current user
        .map((entry) {
      return {
        'userId': entry.key,
        'name': entry.value['name'],
        'photoUrl': entry.value['photoUrl'],
        'isActive': entry.value['isActive'] ?? false,
      };
    }).toList();

    if (allParticipants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others to join...',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: allParticipants.length <= 4 ? 2 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: allParticipants.length,
      itemBuilder: (context, index) {
        final participant = allParticipants[index];
        final isCurrentUser = participant['userId'] == widget.userId;

        return _buildParticipantCard(
          participant['name'] ?? 'Unknown',
          participant['photoUrl'],
          isCurrentUser,
          participant['isActive'] ?? false,
        );
      },
    );
  }

  Widget _buildParticipantCard(String name, String? photoUrl, bool isCurrentUser, bool isActive) {
    // CRITICAL FIX: Determine correct status text
    // - Caller (isCurrentUser=true, viewing OTHER participants who are not active) should see: "Ringing..."
    // - Other participants (isCurrentUser=false, not active) should display: "Ringing..."
    // - Active participants should show: "Connected" or "Muted"
    // NOTE: This card shows OTHER participants, NOT the current user themselves

    String statusText;
    Color statusColor;

    if (!isActive) {
      // Participant hasn't joined yet - always show "Ringing..."
      statusText = 'Ringing...';
      statusColor = Colors.orange.withValues(alpha: 0.8);
    } else if (_isMuted && isCurrentUser) {
      // This shouldn't happen since isCurrentUser check in grid excludes caller
      // But keeping as fallback
      statusText = 'Muted';
      statusColor = Colors.red.withValues(alpha: 0.8);
    } else {
      // Participant is active/connected
      statusText = 'Connected';
      statusColor = Colors.green.withValues(alpha: 0.8);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentUser
              ? [const Color(0xFF5856D6), const Color(0xFF007AFF)]
              : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile picture with pulse/waveform animation
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Profile image
                  ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.iosBlue.withValues(alpha: 0.2),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.iosBlue.withValues(alpha: 0.2),
                              child: Center(
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.iosBlue.withValues(alpha: 0.2),
                            child: Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Waveform overlay when active/speaking
                  if (isActive && !_isMuted)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: _buildMiniWaveform(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            isCurrentUser ? 'You' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Status indicator
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final heights = [3.0, 6.0, 4.0, 8.0, 5.0, 7.0, 4.0, 6.0];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 2,
          height: heights[index],
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            onTap: _toggleMute,
            backgroundColor: _isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
            iconColor: _isMuted ? Colors.white : Colors.white70,
          ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            onTap: _endCall,
            backgroundColor: Colors.red,
            iconColor: Colors.white,
            size: 64,
          ),

          // Speaker button
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            onTap: _toggleSpeaker,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            iconColor: Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}
