import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../widgets/floating_particles.dart';
import '../../services/other services/voice_call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final UserProfile otherUser;
  final bool isOutgoing;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    required this.isOutgoing,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VoiceCallService _voiceCallService = VoiceCallService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _callStatus = 'calling';
  Timer? _callTimer;
  Timer? _callTimeoutTimer; // Timer to mark call as missed if not answered
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Speaker on by default
  StreamSubscription? _callSubscription;
  bool _webrtcConnected = false;
  bool _isEndingCall = false; // Flag to prevent multiple end call clicks

  static const int _callTimeoutSeconds = 39; // Mark as missed after 39 seconds

  @override
  void initState() {
    super.initState();
    debugPrint(
      '  VoiceCallScreen: initState - callId=${widget.callId}, isOutgoing=${widget.isOutgoing}, otherUser=${widget.otherUser.name} (${widget.otherUser.uid})',
    );

    // Initialize animation synchronously - MUST happen before first build
    _setupAnimation();

    // Use post-frame callback for async operations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCall();
    });
  }

  void _initializeCall() {
    try {
      debugPrint('  VoiceCallScreen: _initializeCall starting');
      _setupVoiceCallService();
      _listenToCallStatus();
      _joinCall();

      // Start timeout timer for outgoing calls
      if (widget.isOutgoing) {
        _startCallTimeout();
      }
      debugPrint('  VoiceCallScreen: _initializeCall completed');
    } catch (e, stackTrace) {
      debugPrint('  VoiceCallScreen: Error in _initializeCall: $e');
      debugPrint('  VoiceCallScreen: Stack trace: $stackTrace');
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: _callTimeoutSeconds), () {
      // If call is still in calling/ringing state after timeout, mark as missed
      if (mounted && (_callStatus == 'calling' || _callStatus == 'ringing')) {
        _markCallAsMissed();
      }
    });
  }

  Future<void> _markCallAsMissed() async {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();

    // Leave WebRTC call
    await _voiceCallService.leaveCall();

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'missed',
        'missedAt': FieldValue.serverTimestamp(),
      });

      // REMOVED: Message saving is now handled by enhanced_chat_screen.dart
      // to prevent duplicate messages
      // if (widget.isOutgoing) {
      //   await _sendCallMessageToChat(isMissed: true, duration: 0);
      // }
    } catch (e) {
      // Error marking call as missed
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // REMOVED: This function was creating duplicate messages
  // Message saving is now centrally handled by enhanced_chat_screen.dart
  // via _checkCallStatusAndAddMessage() to prevent duplicates

  void _setupVoiceCallService() {
    _voiceCallService.onUserJoined = (uid) {
      if (mounted) {
        setState(() {
          _webrtcConnected = true;
        });
      }
    };

    _voiceCallService.onUserOffline = (uid) {
      if (mounted) {
        setState(() {
          _webrtcConnected = false;
        });
      }
    };

    _voiceCallService.onError = (message) {
      // Error handled silently - no snackbar
      debugPrint('VoiceCall error: $message');
    };
  }

  Future<void> _joinCall() async {
    debugPrint(
      '  VoiceCallScreen: _joinCall starting - callId=${widget.callId}, isCaller=${widget.isOutgoing}',
    );

    try {
      // Small delay to ensure screen is fully mounted before joining call
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) {
        debugPrint('  VoiceCallScreen: Not mounted, skipping joinCall');
        return;
      }

      final success = await _voiceCallService.joinCall(
        widget.callId,
        isCaller: widget.isOutgoing,
      );

      if (!success && mounted) {
        debugPrint('  VoiceCallScreen: Failed to connect audio');
      } else {
        debugPrint(
          '  VoiceCallScreen: Audio connection initiated successfully',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('  VoiceCallScreen: Error in _joinCall: $e');
      debugPrint('  VoiceCallScreen: Stack trace: $stackTrace');
    }
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _listenToCallStatus() {
    debugPrint(
      '  VoiceCallScreen: _listenToCallStatus started for callId=${widget.callId}, isOutgoing=${widget.isOutgoing}',
    );

    // Flag to track if we've seen a connected status to prevent early termination
    bool hasBeenConnected = false;
    // Skip the first snapshot to avoid acting on stale data
    bool isFirstSnapshot = true;

    _callSubscription = _firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) {
              debugPrint(
                '  VoiceCallScreen: Not mounted, ignoring status update',
              );
              return;
            }

            // Check if document exists
            if (!snapshot.exists) {
              debugPrint(
                '  VoiceCallScreen: Call document does not exist - ignoring',
              );
              return;
            }

            final data = snapshot.data();
            if (data == null) {
              debugPrint(
                '  VoiceCallScreen: Call document data is null - ignoring',
              );
              return;
            }

            final status = data['status'] as String? ?? 'calling';
            final previousStatus = _callStatus;

            debugPrint(
              '  VoiceCallScreen: Received status=$status, previous=$previousStatus, isFirst=$isFirstSnapshot',
            );

            // For receiver (isOutgoing=false), we expect status to be 'connected' when we arrive
            // Don't end the call on first snapshot if status is already connected
            if (isFirstSnapshot) {
              isFirstSnapshot = false;

              // If we're receiver and status is connected, that's expected - we just accepted the call
              if (!widget.isOutgoing && status == 'connected') {
                debugPrint(
                  '  VoiceCallScreen: Receiver - call already connected, starting timer',
                );
                hasBeenConnected = true;
                _callTimeoutTimer?.cancel();
                setState(() {
                  _callStatus = status;
                });
                _startCallTimer();
                return;
              }

              // If status is already ended/missed/rejected on first load, it's stale - end gracefully
              if (status == 'ended' ||
                  status == 'missed' ||
                  status == 'rejected' ||
                  status == 'declined') {
                debugPrint(
                  '  VoiceCallScreen: First snapshot shows call already ended ($status) - closing',
                );
                _endCall(wasMissedOrDeclined: true, skipMessage: true);
                return;
              }
            }

            // Skip if status hasn't changed
            if (status == previousStatus) {
              return;
            }

            debugPrint(
              '  VoiceCallScreen: Call status changed: $previousStatus -> $status (isOutgoing=${widget.isOutgoing})',
            );

            setState(() {
              _callStatus = status;
            });

            if (status == 'connected' || status == 'accepted') {
              debugPrint(
                '  VoiceCallScreen: Call connected/accepted - starting timer',
              );
              hasBeenConnected = true;
              // Cancel timeout timer since call is connected
              _callTimeoutTimer?.cancel();
              _startCallTimer();
              // Update status to connected if it was accepted (only from caller side to avoid race)
              if (status == 'accepted' && widget.isOutgoing) {
                debugPrint(
                  '  VoiceCallScreen: Caller updating status from accepted to connected',
                );
                _firestore.collection('calls').doc(widget.callId).update({
                  'status': 'connected',
                  'connectedAt': FieldValue.serverTimestamp(),
                });
              }
            } else if (status == 'ringing') {
              debugPrint('  VoiceCallScreen: Call is ringing on receiver side');
              // Just update UI - call is still in progress
            } else if (status == 'ended' ||
                status == 'declined' ||
                status == 'rejected' ||
                status == 'missed') {
              // Only end call if it was previously connected OR if we're the caller
              // This prevents premature termination when receiver just joined
              if (hasBeenConnected ||
                  widget.isOutgoing ||
                  previousStatus == 'connected') {
                debugPrint(
                  '  VoiceCallScreen: Call ended/declined/rejected/missed - ending call (hasBeenConnected=$hasBeenConnected)',
                );
                _callTimeoutTimer?.cancel();
                _endCall(
                  wasMissedOrDeclined:
                      status == 'declined' ||
                      status == 'rejected' ||
                      status == 'missed',
                  // Don't send message if rejected - IncomingCallScreen already sent it
                  skipMessage: status == 'rejected',
                );
              } else {
                debugPrint(
                  '  VoiceCallScreen: Ignoring $status status - call not yet established for receiver',
                );
              }
            }
          },
          onError: (e) {
            debugPrint('  VoiceCallScreen: Error listening to call status: $e');
          },
        );
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall({
    bool wasMissedOrDeclined = false,
    bool skipMessage = false,
  }) async {
    //   Prevent multiple simultaneous end call operations
    if (_isEndingCall) {
      debugPrint(
        '  VoiceCallScreen: Already ending call, ignoring duplicate request',
      );
      return;
    }
    _isEndingCall = true;

    debugPrint(
      '  VoiceCallScreen: _endCall started (wasMissedOrDeclined=$wasMissedOrDeclined, skipMessage=$skipMessage)',
    );

    // Provide immediate UI feedback by popping screen first
    if (mounted) {
      debugPrint(
        '  VoiceCallScreen: Popping screen immediately for instant feedback',
      );
      Navigator.of(context).pop();
    }

    // Cancel timers and subscriptions first
    try {
      _callTimer?.cancel();
      _callTimer = null;
    } catch (e) {
      debugPrint('  VoiceCallScreen: Error cancelling call timer: $e');
    }

    try {
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = null;
    } catch (e) {
      debugPrint('  VoiceCallScreen: Error cancelling timeout timer: $e');
    }

    try {
      _callSubscription?.cancel();
      _callSubscription = null;
    } catch (e) {
      debugPrint('  VoiceCallScreen: Error cancelling subscription: $e');
    }

    // Leave WebRTC call
    try {
      await _voiceCallService.leaveCall();
    } catch (e) {
      debugPrint('  VoiceCallScreen: Error leaving WebRTC call: $e');
    }

    //   FIXED: Determine if this was a missed/declined call or completed call
    // A call is considered "answered/connected" if:
    // 1. It was NOT explicitly marked as missed/declined AND
    // 2. Call duration is greater than 0 (means call timer started) OR status is 'connected'
    final bool wasConnected =
        !wasMissedOrDeclined &&
        (_callDuration > 0 || _callStatus == 'connected');
    final bool wasMissed = !wasConnected;

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': wasMissed ? 'missed' : 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callDuration,
      });
      debugPrint(
        '  VoiceCallScreen: Updated call status in Firestore (wasConnected=$wasConnected, wasMissed=$wasMissed, duration=$_callDuration, _callStatus=$_callStatus)',
      );

      // REMOVED: Message saving is now handled by enhanced_chat_screen.dart
      // to prevent duplicate messages
      // if (!skipMessage) {
      //   await _sendCallMessageToChat(
      //     isMissed: wasMissed,
      //     duration: _callDuration,
      //   );
      // }
    } catch (e) {
      debugPrint('  VoiceCallScreen: Error updating call status: $e');
    }

    // Screen already popped at the start for instant feedback
    debugPrint('  VoiceCallScreen: Call ended successfully');
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    _voiceCallService.toggleMute();
    setState(() {
      _isMuted = _voiceCallService.isMuted;
    });
  }

  void _toggleSpeaker() {
    HapticFeedback.lightImpact();
    _voiceCallService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = _voiceCallService.isSpeakerOn;
    });
  }

  @override
  void dispose() {
    debugPrint('  VoiceCallScreen: dispose called');
    try {
      _callTimer?.cancel();
      _callTimer = null;
    } catch (_) {}
    try {
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = null;
    } catch (_) {}
    try {
      _callSubscription?.cancel();
      _callSubscription = null;
    } catch (_) {}
    try {
      _voiceCallService.leaveCall();
    } catch (_) {}
    try {
      _pulseController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset:
          false, // Prevent keyboard/input from affecting layout
      extendBodyBehindAppBar: false, // Don't extend body behind app bar
      body: Stack(
        children: [
          // Background Image (same as home screen)
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

          // Blur effect with dark overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          // Floating particles
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildUserInfo(),
                const SizedBox(height: 40),
                _buildCallStatus(),
                const Spacer(),
                _buildCallControls(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _callStatus == 'calling' ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.phone, size: 70, color: Colors.white),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          widget.otherUser.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.otherUser.location != null)
          Text(
            widget.otherUser.location!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildCallStatus() {
    String statusText;
    Color statusColor;

    switch (_callStatus) {
      case 'calling':
        statusText = widget.isOutgoing ? 'Calling...' : 'Incoming call...';
        statusColor = Colors.amber;
        break;
      case 'ringing':
        statusText = 'Ringing...';
        statusColor = Colors.amber;
        break;
      case 'connected':
        statusText = _formatDuration(_callDuration);
        statusColor = Colors.green;
        break;
      case 'ended':
        statusText = 'Call ended';
        statusColor = Colors.red;
        break;
      case 'declined':
        statusText = 'Call declined';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Connecting...';
        statusColor = Colors.blue;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_callStatus == 'connected')
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // WebRTC connection indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _webrtcConnected ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _webrtcConnected ? 'Audio connected' : 'Connecting audio...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Voice Call',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCallControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: _toggleMute,
              isActive: _isMuted,
            ),
            const SizedBox(width: 40),
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: 'Speaker',
              onTap: _toggleSpeaker,
              isActive: _isSpeakerOn,
            ),
          ],
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => _endCall(),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.red, blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'End Call',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
