import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'group_audio_call_screen.dart';
import '../../res/config/app_colors.dart';

/// Incoming Group Audio Call Screen
class IncomingGroupAudioCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhotoUrl;
  final List<Map<String, dynamic>> participants;
  final String currentUserId;

  const IncomingGroupAudioCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.participants,
    required this.currentUserId,
  });

  @override
  State<IncomingGroupAudioCallScreen> createState() =>
      _IncomingGroupAudioCallScreenState();
}

class _IncomingGroupAudioCallScreenState
    extends State<IncomingGroupAudioCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Note: Deduplication is now handled in GroupAudioCallScreen.initState
    debugPrint('🎙️ IncomingGroupAudioCallScreen: ${widget.participants.length} participants');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    try {
      // Update participant status to active
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.currentUserId)
          .update({'isActive': true, 'joinedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;

      // Get current user info
      final userDoc =
          await _firestore.collection('users').doc(widget.currentUserId).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      // Navigate to group audio call screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GroupAudioCallScreen(
            callId: widget.callId,
            userId: widget.currentUserId,
            userName: userName,
            participants: widget.participants,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
      }
    }
  }

  Future<void> _rejectCall() async {
    try {
      // Update participant status to inactive (rejected)
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.currentUserId)
          .update({'isActive': false});

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error rejecting call: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            // Caller info
            const Text(
              'Group Audio Call',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),

            // Caller avatar with pulse animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5856D6).withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.callerPhotoUrl != null &&
                          widget.callerPhotoUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.callerPhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.iosBlue.withValues(alpha: 0.2),
                            child: const Center(
                              child: Icon(Icons.person,
                                  size: 60, color: Colors.white),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.iosBlue.withValues(alpha: 0.2),
                            child: Center(
                              child: Text(
                                widget.callerName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 60,
                                  color: Colors.white,
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
                              widget.callerName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 60,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Caller name
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Participant count
            Text(
              '${widget.participants.length} participant${widget.participants.length != 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            // Call status
            const Text(
              'Incoming audio call...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),

            const Spacer(),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  GestureDetector(
                    onTap: _rejectCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Accept button
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
