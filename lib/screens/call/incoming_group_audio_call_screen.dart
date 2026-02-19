import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/config/app_colors.dart';
import '../../widgets/floating_particles.dart';
import 'group_audio_call_screen.dart';

class IncomingGroupAudioCallScreen extends StatefulWidget {
  final String callId;
  final String groupId;
  final String groupName;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String currentUserId;
  final String currentUserName;
  final List<dynamic> participants;

  const IncomingGroupAudioCallScreen({
    super.key,
    required this.callId,
    required this.groupId,
    required this.groupName,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.currentUserId,
    required this.currentUserName,
    required this.participants,
  });

  @override
  State<IncomingGroupAudioCallScreen> createState() =>
      _IncomingGroupAudioCallScreenState();
}

class _IncomingGroupAudioCallScreenState
    extends State<IncomingGroupAudioCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAccepting = false;
  Timer? _autoRejectTimer;
  StreamSubscription? _callStatusListener;
  StreamSubscription? _callerStatusListener;

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

    // Start 39-second auto-reject timer
    _startAutoRejectTimer();

    // Listen for call status changes (if caller ends call)
    _listenToCallStatus();

    // Listen specifically for caller's participant status
    _listenToCallerStatus();
  }

  @override
  void dispose() {
    _autoRejectTimer?.cancel();
    _callStatusListener?.cancel();
    _callerStatusListener?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAutoRejectTimer() {
    // Auto-dismiss after 39 seconds if not answered
    _autoRejectTimer = Timer(const Duration(seconds: 39), () async {
      if (mounted && !_isAccepting) {
        debugPrint('IncomingCall: 39 seconds timeout - auto-rejecting');
        await _declineCall();
      }
    });
  }

  void _listenToCallStatus() {
    // Listen for call status changes (e.g., if caller cancels)
    _callStatusListener = FirebaseFirestore.instance
        .collection('group_calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;

          if (!snapshot.exists) {
            // Call deleted - dismiss screen
            debugPrint('IncomingCall: Call deleted - dismissing');
            if (mounted) Navigator.pop(context);
            return;
          }

          final data = snapshot.data();
          final status = data?['status'] as String?;

          // If call ended or cancelled, dismiss screen
          if (status == 'ended' || status == 'cancelled') {
            debugPrint('IncomingCall: Call $status - dismissing');
            if (mounted) Navigator.pop(context);
            return;
          }

          // Check if caller has left before anyone joined
          try {
            final callerId = data?['callerId'] as String?;
            if (callerId != null && callerId == widget.callerId) {
              // Check caller's participant status
              final callerParticipantDoc = await FirebaseFirestore.instance
                  .collection('group_calls')
                  .doc(widget.callId)
                  .collection('participants')
                  .doc(callerId)
                  .get();

              if (callerParticipantDoc.exists) {
                final callerData = callerParticipantDoc.data();
                final callerActive = callerData?['isActive'] as bool? ?? false;

                // If caller is no longer active, dismiss incoming screen
                if (!callerActive) {
                  debugPrint(
                    'IncomingCall: Caller ($callerId) has left - dismissing',
                  );
                  if (mounted) Navigator.pop(context);
                }
              }
            }
          } catch (e) {
            debugPrint('IncomingCall: Error checking caller status: $e');
          }
        });
  }

  void _listenToCallerStatus() {
    // Listen specifically to caller's participant status for immediate detection
    _callerStatusListener = FirebaseFirestore.instance
        .collection('group_calls')
        .doc(widget.callId)
        .collection('participants')
        .doc(widget.callerId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          if (!snapshot.exists) {
            // Caller participant doc deleted - dismiss
            debugPrint('IncomingCall: Caller participant deleted - dismissing');
            if (mounted) Navigator.pop(context);
            return;
          }

          final data = snapshot.data();
          final callerActive = data?['isActive'] as bool? ?? false;

          // If caller is no longer active, dismiss incoming screen immediately
          if (!callerActive) {
            debugPrint(
              'IncomingCall: Caller (${widget.callerId}) became inactive - dismissing',
            );
            if (mounted) Navigator.pop(context);
          }
        });
  }

  Future<void> _acceptCall() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    // Cancel auto-reject timer since user is accepting
    _autoRejectTimer?.cancel();

    try {
      // Update status to active
      await FirebaseFirestore.instance
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.currentUserId)
          .update({'isActive': true});

      if (mounted) {
        // Prepare participants list for the next screen
        final List<Map<String, dynamic>> participantList = widget.participants
            .map((p) {
              if (p is Map<String, dynamic>) return p;
              return {'userId': p.toString(), 'name': 'User', 'photoUrl': null};
            })
            .toList();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GroupAudioCallScreen(
              callId: widget.callId,
              groupId: widget.groupId,
              userId: widget.currentUserId,
              userName: widget.currentUserName,
              groupName: widget.groupName,
              participants: participantList,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting call: $e');
      setState(() => _isAccepting = false);
    }
  }

  Future<void> _declineCall() async {
    try {
      await FirebaseFirestore.instance
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.currentUserId)
          .update({'isActive': false});

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error declining call: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.splashGradient,
              ),
            ),
          ),

          // Particles
          const Positioned.fill(child: FloatingParticles(particleCount: 15)),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Top Center: Profile Icon / Avatar
                Center(
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: widget.callerPhoto != null
                            ? CachedNetworkImage(
                                imageUrl: widget.callerPhoto!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Icon(
                                  Icons.group_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.group_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Caller Name & Info
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Incoming group call from ${widget.callerName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // Bottom Action Buttons (Red Left, Green Right)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 60,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline Button (Left - Red)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _declineCall,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30), // Red
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF3B30,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
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
                          const SizedBox(height: 12),
                          const Text(
                            'Decline',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // Accept Button (Right - Green)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _acceptCall,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366), // Green
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF25D366,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: _isAccepting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      Icons.call,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
        ],
      ),
    );
  }
}
