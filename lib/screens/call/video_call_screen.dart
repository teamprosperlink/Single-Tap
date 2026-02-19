import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../widgets/safe_circle_avatar.dart';
import '../../services/other services/video_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final UserProfile otherUser;
  final bool isOutgoing;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.otherUser,
    required this.isOutgoing,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final VideoCallService _videoCallService = VideoCallService();

  String _callStatus = 'calling';
  Timer? _callTimer;
  Timer? _callTimeoutTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  StreamSubscription? _callSubscription;
  Timer? _hideControlsTimer;
  bool _isEndingCall = false; // Flag to prevent multiple end call clicks
  bool _renderersInitialized = false; // Track renderer initialization
  bool _localStreamReady = false; // Track local stream status
  bool _remoteStreamReady = false; // Track remote stream status

  static const int _callTimeoutSeconds = 60;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '  VideoCallScreen: initState - callId=${widget.callId}, isOutgoing=${widget.isOutgoing}',
    );

    // Initialize renderers immediately to ensure they're ready for RTCVideoView
    _initializeRenderers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCall();
    });
  }

  Future<void> _initializeRenderers() async {
    try {
      debugPrint('  VideoCallScreen: Initializing renderers explicitly...');

      // Initialize video call service first (this initializes renderers)
      final initialized = await _videoCallService.initialize();

      if (initialized) {
        debugPrint('  VideoCallScreen:   Renderers initialized successfully');
        if (mounted) {
          setState(() {
            _renderersInitialized = true;
          });
        }
      } else {
        debugPrint('  VideoCallScreen:   Failed to initialize renderers');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to initialize camera. Please check permissions.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('  VideoCallScreen: Error initializing renderers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeCall() {
    try {
      debugPrint('  VideoCallScreen: _initializeCall starting');
      _setupVideoCallService();
      _listenToCallStatus();
      _joinCall();

      if (widget.isOutgoing) {
        _startCallTimeout();
      }
      debugPrint('  VideoCallScreen: _initializeCall completed');
    } catch (e, stackTrace) {
      debugPrint('  VideoCallScreen: Error in _initializeCall: $e');
      debugPrint('  VideoCallScreen: Stack trace: $stackTrace');
    }
  }

  void _setupVideoCallService() {
    _videoCallService.onUserJoined = (uid) {
      if (mounted) {
        setState(() {
          _callStatus = 'connected';
        });
        debugPrint(
          '  VideoCallScreen:   User joined (uid=$uid), _callStatus set to CONNECTED, starting timer',
        );
        _startCallTimer();

        //   FIX: Force UI rebuild after connection to ensure video displays
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              // Trigger rebuild to ensure videos are showing
            });
            debugPrint(
              '  VideoCallScreen: 🔄 Forced UI rebuild after user joined',
            );
          }
        });
      }
    };

    _videoCallService.onUserOffline = (uid) {
      if (mounted) {
        debugPrint('  VideoCallScreen: User offline');
        _endCall();
      }
    };

    _videoCallService.onError = (error) {
      if (mounted) {
        debugPrint('  VideoCallScreen: Error callback - $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        // If it's a critical error, end the call
        if (error.contains('not supported') ||
            error.contains('UnimplementedError')) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _endCall();
            }
          });
        }
      }
    };

    // NEW: Handle remote stream ready - force UI rebuild to show video
    _videoCallService.onRemoteStreamReady = () {
      if (mounted) {
        debugPrint(
          '  VideoCallScreen: 🎥 Remote stream ready - rebuilding UI to show video',
        );
        setState(() {
          _remoteStreamReady = true;
        });
        //   FIX: Force another rebuild after a short delay to ensure renderer is fully updated
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              // Just trigger rebuild, state already set
            });
            debugPrint(
              '  VideoCallScreen: 🔄 Forced UI rebuild for remote video',
            );
          }
        });
      }
    };

    // NEW: Handle local stream ready - force UI rebuild to show own video
    _videoCallService.onLocalStreamReady = () {
      if (mounted) {
        debugPrint(
          '  VideoCallScreen: 📹 Local stream ready - rebuilding UI to show own video',
        );
        setState(() {
          _localStreamReady = true;
        });
        //   FIX: Force another rebuild after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              // Just trigger rebuild, state already set
            });
            debugPrint(
              '  VideoCallScreen: 🔄 Forced UI rebuild for local video',
            );
          }
        });
      }
    };
  }

  void _listenToCallStatus() {
    debugPrint(
      '  VideoCallScreen: _listenToCallStatus started for callId=${widget.callId}, isOutgoing=${widget.isOutgoing}',
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
                '  VideoCallScreen: Not mounted, ignoring status update',
              );
              return;
            }

            // Check if document exists
            if (!snapshot.exists) {
              debugPrint(
                '  VideoCallScreen: Call document does not exist - ignoring',
              );
              return;
            }

            final data = snapshot.data();
            if (data == null) {
              debugPrint(
                '  VideoCallScreen: Call document data is null - ignoring',
              );
              return;
            }

            final status = data['status'] as String? ?? 'calling';
            final previousStatus = _callStatus;

            debugPrint(
              '  VideoCallScreen: Received status=$status, previous=$previousStatus, isFirst=$isFirstSnapshot',
            );

            // For receiver (isOutgoing=false), we expect status to be 'connected' when we arrive
            // Don't end the call on first snapshot if status is already connected
            if (isFirstSnapshot) {
              isFirstSnapshot = false;

              // If we're receiver and status is connected, that's expected - we just accepted the call
              if (!widget.isOutgoing && status == 'connected') {
                debugPrint(
                  '  VideoCallScreen: Receiver - call already connected, starting timer',
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
                  '  VideoCallScreen: First snapshot shows call already ended ($status) - closing',
                );
                _endCall();
                return;
              }
            }

            // Skip if status hasn't changed
            if (status == previousStatus) {
              return;
            }

            debugPrint(
              '  VideoCallScreen: Call status changed: $previousStatus -> $status (isOutgoing=${widget.isOutgoing})',
            );

            setState(() {
              _callStatus = status;
            });

            if (status == 'connected' || status == 'accepted') {
              debugPrint(
                '  VideoCallScreen: Call connected/accepted - starting timer',
              );
              hasBeenConnected = true;
              // Cancel timeout timer since call is connected
              _callTimeoutTimer?.cancel();
              _startCallTimer();
              // Update status to connected if it was accepted (only from caller side to avoid race)
              if (status == 'accepted' && widget.isOutgoing) {
                debugPrint(
                  '  VideoCallScreen: Caller updating status from accepted to connected',
                );
                _firestore.collection('calls').doc(widget.callId).update({
                  'status': 'connected',
                  'connectedAt': FieldValue.serverTimestamp(),
                });
              }
            } else if (status == 'ringing') {
              debugPrint('  VideoCallScreen: Call is ringing on receiver side');
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
                  '  VideoCallScreen: Call ended/declined/rejected/missed - ending call (hasBeenConnected=$hasBeenConnected)',
                );
                _callTimeoutTimer?.cancel();
                _endCall();
              } else {
                debugPrint(
                  '  VideoCallScreen: Ignoring $status status - call not yet established for receiver',
                );
              }
            }
          },
          onError: (e) {
            debugPrint('  VideoCallScreen: Error listening to call status: $e');
          },
        );
  }

  void _joinCall() {
    _videoCallService
        .joinCall(widget.callId, isCaller: widget.isOutgoing)
        .then((success) {
          debugPrint('  VideoCallScreen: joinCall result=$success');
          if (!success && mounted) {
            debugPrint('  VideoCallScreen: Join call failed, ending call...');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _endCall();
              }
            });
          }
        })
        .catchError((e) {
          debugPrint('  VideoCallScreen: Error in _joinCall: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to join call: ${e.toString()}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );

            // End call after showing error
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _endCall();
              }
            });
          }
        });
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: _callTimeoutSeconds), () {
      if (mounted && (_callStatus == 'calling' || _callStatus == 'ringing')) {
        _markCallAsMissed();
      }
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callStatus == 'connected') {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  Future<void> _markCallAsMissed() async {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();
    _hideControlsTimer?.cancel();

    await _videoCallService.hangup();

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
      debugPrint('  VideoCallScreen: Error marking call as missed: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // REMOVED: This function was creating duplicate messages
  // Message saving is now centrally handled by enhanced_chat_screen.dart
  // via _checkCallStatusAndAddMessage() to prevent duplicates

  Future<void> _endCall() async {
    //   Prevent multiple simultaneous end call operations
    if (_isEndingCall) {
      debugPrint(
        '  VideoCallScreen: Already ending call, ignoring duplicate request',
      );
      return;
    }
    _isEndingCall = true;

    debugPrint('  VideoCallScreen: _endCall started');

    // Provide immediate UI feedback by popping screen first
    if (mounted) {
      debugPrint(
        '  VideoCallScreen: Popping screen immediately for instant feedback',
      );
      Navigator.of(context).pop();
    }

    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();
    _hideControlsTimer?.cancel();

    //   FIXED: Determine if call was actually connected based on BOTH status AND duration
    // A call is considered "answered/connected" if:
    // 1. Status is 'connected' OR
    // 2. Call duration is greater than 0 (means call timer started)
    final wasConnected = _callStatus == 'connected' || _callDuration > 0;
    final callStatus = wasConnected ? 'ended' : 'missed';

    debugPrint(
      '  VideoCallScreen: _endCall - _callStatus=$_callStatus, _callDuration=$_callDuration, wasConnected=$wasConnected, setting status=$callStatus',
    );

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': callStatus,
        'endedAt': FieldValue.serverTimestamp(),
        'duration': _callDuration,
      });

      debugPrint(
        '  VideoCallScreen:   Call status saved to Firestore (status=$callStatus, duration=$_callDuration)',
      );

      // REMOVED: Message saving is now handled by enhanced_chat_screen.dart
      // to prevent duplicate messages
      // await _sendCallMessageToChat(
      //   isMissed: false,
      //   duration: duration,
      // );
    } catch (e) {
      debugPrint('  VideoCallScreen: Error ending call: $e');
    }

    await _videoCallService.hangup();

    // Screen already popped at the start for instant feedback
    debugPrint('  VideoCallScreen: Call ended successfully');
  }

  Future<void> _toggleMute() async {
    // Immediate visual feedback
    if (mounted) {
      setState(() {
        _isMuted = !_isMuted;
      });
    }

    try {
      await _videoCallService.toggleMute();
      debugPrint('  VideoCallScreen: Mute toggled - $_isMuted');
    } catch (e) {
      debugPrint('  VideoCallScreen: Error toggling mute: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isMuted = !_isMuted;
        });
      }
    }
  }

  Future<void> _toggleSpeaker() async {
    // Immediate visual feedback
    if (mounted) {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });
    }

    try {
      await _videoCallService.toggleSpeaker();
      debugPrint('  VideoCallScreen: Speaker toggled - $_isSpeakerOn');
    } catch (e) {
      debugPrint('  VideoCallScreen: Error toggling speaker: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isSpeakerOn = !_isSpeakerOn;
        });
      }
    }
  }

  Future<void> _toggleVideo() async {
    // Immediate visual feedback
    if (mounted) {
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    }

    try {
      await _videoCallService.toggleVideo();
      debugPrint('  VideoCallScreen: Video toggled - $_isVideoEnabled');
    } catch (e) {
      debugPrint('  VideoCallScreen: Error toggling video: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isVideoEnabled = !_isVideoEnabled;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    // Immediate visual feedback
    if (mounted) {
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
    }

    try {
      await _videoCallService.switchCamera();
      debugPrint(
        '  VideoCallScreen: Camera switched - ${_isFrontCamera ? "front" : "back"}',
      );
    } catch (e) {
      debugPrint('  VideoCallScreen: Error switching camera: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isFrontCamera = !_isFrontCamera;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSubscription?.cancel();
    _hideControlsTimer?.cancel();
    _videoCallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Log renderer state on every build
    final hasLocalVideo =
        _videoCallService.localRenderer.srcObject != null &&
        _videoCallService.localRenderer.textureId != null;
    final hasRemoteVideo =
        _videoCallService.remoteRenderer.srcObject != null &&
        _videoCallService.remoteRenderer.textureId != null;
    final localStream = _videoCallService.localRenderer.srcObject;
    final remoteStream = _videoCallService.remoteRenderer.srcObject;
    final localTextureId = _videoCallService.localRenderer.textureId;
    final remoteTextureId = _videoCallService.remoteRenderer.textureId;

    final localVideoTracks = localStream?.getVideoTracks() ?? [];
    final remoteVideoTracks = remoteStream?.getVideoTracks() ?? [];
    final localVideoEnabled = localVideoTracks.isNotEmpty
        ? localVideoTracks.first.enabled
        : false;
    final remoteVideoEnabled = remoteVideoTracks.isNotEmpty
        ? remoteVideoTracks.first.enabled
        : false;

    // CRITICAL DEBUG: Log every detail about video rendering
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('  VideoCallScreen BUILD:');
    debugPrint('    Call Status: $_callStatus');
    debugPrint('    Renderers Initialized: $_renderersInitialized');
    debugPrint('    Local Stream Ready: $_localStreamReady');
    debugPrint('    Remote Stream Ready: $_remoteStreamReady');
    debugPrint('    Video Enabled: $_isVideoEnabled');
    debugPrint('  LOCAL VIDEO:');
    debugPrint('    hasLocalVideo: $hasLocalVideo');
    debugPrint('    textureId: $localTextureId');
    debugPrint('    srcObject: ${localStream != null}');
    debugPrint('    video tracks: ${localVideoTracks.length}');
    debugPrint('    track enabled: $localVideoEnabled');
    debugPrint('  REMOTE VIDEO:');
    debugPrint('    hasRemoteVideo: $hasRemoteVideo');
    debugPrint('    textureId: $remoteTextureId');
    debugPrint('    srcObject: ${remoteStream != null}');
    debugPrint('    video tracks: ${remoteVideoTracks.length}');
    debugPrint('    track enabled: $remoteVideoEnabled');
    debugPrint('═══════════════════════════════════════════════════════');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset:
            false, // Prevent keyboard/input from affecting layout
        extendBodyBehindAppBar: false, // Don't extend body behind app bar
        body: Stack(
          children: [
            // Show appropriate video based on call status
            if (_callStatus == 'connected')
              // When connected, show remote video fullscreen
              Positioned.fill(
                child: hasRemoteVideo
                    ? Stack(
                        children: [
                          // Remote video
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              child: RTCVideoView(
                                _videoCallService.remoteRenderer,
                                key: ValueKey(
                                  'remote_${_videoCallService.remoteRenderer.textureId}_$_remoteStreamReady',
                                ),
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                                mirror: false,
                              ),
                            ),
                          ),
                          // Debug indicator (top-left corner)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'REMOTE VIDEO ON',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SafeCircleAvatar(
                                photoUrl: widget.otherUser.photoUrl,
                                radius: 80,
                                name: widget.otherUser.name,
                              ),
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Connecting video...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Debug info
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'DEBUG: Remote Video Not Ready',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'hasRemoteVideo: $hasRemoteVideo\n'
                                      'textureId: $remoteTextureId\n'
                                      'srcObject: ${remoteStream != null}\n'
                                      'tracks: ${remoteVideoTracks.length}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              )
            else
              // When calling/ringing, show local camera fullscreen
              Positioned.fill(
                child: hasLocalVideo
                    ? Stack(
                        children: [
                          // Local video
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              child: RTCVideoView(
                                _videoCallService.localRenderer,
                                key: ValueKey(
                                  'local_${_videoCallService.localRenderer.textureId}_$_localStreamReady',
                                ),
                                mirror: _isFrontCamera,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                              ),
                            ),
                          ),
                          // Debug indicator (top-left corner)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LOCAL VIDEO ON',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SafeCircleAvatar(
                                photoUrl: widget.otherUser.photoUrl,
                                radius: 80,
                                name: widget.otherUser.name,
                              ),
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Starting camera...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

            // When connected, show local video as Picture-in-Picture (SingleTap style - top right)
            if (_callStatus == 'connected' && hasLocalVideo && _isVideoEnabled)
              Positioned(
                top: 60,
                right: 16,
                width: 100,
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: RTCVideoView(
                      _videoCallService.localRenderer,
                      key: ValueKey(
                        'pip_${_videoCallService.localRenderer.textureId}_$_localStreamReady',
                      ),
                      mirror: _isFrontCamera,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Show other user info overlay when calling/ringing
            if (_callStatus != 'connected')
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SafeCircleAvatar(
                          photoUrl: widget.otherUser.photoUrl,
                          radius: 80,
                          name: widget.otherUser.name,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.otherUser.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _callStatus == 'calling'
                              ? 'Calling...'
                              : _callStatus == 'ringing'
                              ? 'Ringing...'
                              : 'Connecting...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top overlay with call info (SingleTap style)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // User name and status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.otherUser.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _callStatus == 'connected'
                                  ? _formatDuration(_callDuration)
                                  : _callStatus == 'calling'
                                  ? 'Calling...'
                                  : 'Ringing...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom control buttons and end call button (SingleTap style)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Control buttons row (SingleTap style - simple and clean)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Camera toggle (Video On/Off)
                          _buildSingleTapControlButton(
                            icon: _isVideoEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            onPressed: _toggleVideo,
                            isActive: _isVideoEnabled,
                          ),

                          // Switch camera (Front/Back)
                          _buildSingleTapControlButton(
                            icon: Icons.flip_camera_android,
                            onPressed: _switchCamera,
                            isActive: true,
                          ),

                          // Mute toggle
                          _buildSingleTapControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            onPressed: _toggleMute,
                            isActive: !_isMuted,
                          ),

                          // Speaker toggle
                          _buildSingleTapControlButton(
                            icon: _isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_down,
                            onPressed: _toggleSpeaker,
                            isActive: _isSpeakerOn,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // End call button (SingleTap style - prominent red button)
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30), // SingleTap red
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFF3B30,
                                ).withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SingleTap-style control button (minimal, clean design)
  Widget _buildSingleTapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.red.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
