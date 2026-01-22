import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/safe_circle_avatar.dart';
import 'group_video_call_screen.dart';

/// Incoming Group Video Call Screen (WhatsApp style)
class IncomingGroupVideoCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhotoUrl;
  final List<Map<String, dynamic>> participants;
  final String currentUserId;

  const IncomingGroupVideoCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.participants,
    required this.currentUserId,
  });

  @override
  State<IncomingGroupVideoCallScreen> createState() => _IncomingGroupVideoCallScreenState();
}

class _IncomingGroupVideoCallScreenState extends State<IncomingGroupVideoCallScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _callSubscription;
  bool _isAnswering = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the avatar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for call status changes
    _listenForCallStatus();
  }

  void _listenForCallStatus() {
    _callSubscription = _firestore
        .collection('group_calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (!snapshot.exists) {
        _decline();
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String? ?? 'ringing';

      if (status == 'ended' || status == 'cancelled') {
        _decline();
      }
    });
  }

  Future<void> _accept() async {
    if (_isAnswering) return;
    setState(() {
      _isAnswering = true;
    });

    try {
      // Update call status
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'status': 'active',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Navigate to group video call screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GroupVideoCallScreen(
            callId: widget.callId,
            userId: widget.currentUserId,
            userName: 'You',
            participants: widget.participants,
          ),
        ),
      );
    } catch (e) {
      debugPrint('  IncomingGroupVideoCallScreen: Error accepting call - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _decline();
    }
  }

  Future<void> _decline() async {
    try {
      // Mark participant as declined
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.currentUserId)
          .update({
        'isActive': false,
        'declined': true,
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('  IncomingGroupVideoCallScreen: Error declining call - $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participantCount = widget.participants.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.grey[900]!,
                  Colors.black,
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Caller avatar with pulse animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: SafeCircleAvatar(
                      photoUrl: widget.callerPhotoUrl,
                      radius: 80,
                      name: widget.callerName,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Call info
                Text(
                  'Group Video Call',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 8),

                // Participant count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$participantCount ${participantCount == 1 ? "participant" : "participants"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Participant avatars preview (max 4)
                if (widget.participants.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _buildParticipantPreview(),
                  ),

                const Spacer(flex: 3),

                // Action buttons (WhatsApp style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      _buildActionButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        color: const Color(0xFFFF3B30),
                        onPressed: _decline,
                      ),

                      // Accept button
                      _buildActionButton(
                        icon: Icons.videocam,
                        label: 'Accept',
                        color: const Color(0xFF34C759),
                        onPressed: _accept,
                        isLoading: _isAnswering,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build participant preview (show up to 4 avatars)
  Widget _buildParticipantPreview() {
    final displayParticipants = widget.participants.take(4).toList();
    final remainingCount = widget.participants.length - 4;

    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Show up to 4 participant avatars overlapping
          ...List.generate(displayParticipants.length, (index) {
            final participant = displayParticipants[index];
            final offset = (index - displayParticipants.length / 2 + 0.5) * 40.0;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + offset - 25,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: SafeCircleAvatar(
                  photoUrl: participant['photoUrl'],
                  radius: 25,
                  name: participant['name'] ?? 'Unknown',
                ),
              ),
            );
          }),

          // Show "+X more" if there are more than 4 participants
          if (remainingCount > 0)
            Positioned(
              right: 0,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build action button (Accept/Decline)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
