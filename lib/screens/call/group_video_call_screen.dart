import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/safe_circle_avatar.dart';
import '../../services/other services/group_video_call_service.dart';

/// WhatsApp-style Group Video Call Screen
/// Supports up to 8 participants with grid layout
class GroupVideoCallScreen extends StatefulWidget {
  final String callId;
  final String userId;
  final String userName;
  final List<Map<String, dynamic>> participants; // List of {userId, name, photoUrl}

  const GroupVideoCallScreen({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
    required this.participants,
  });

  @override
  State<GroupVideoCallScreen> createState() => _GroupVideoCallScreenState();
}

class _GroupVideoCallScreenState extends State<GroupVideoCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupVideoCallService _groupVideoService = GroupVideoCallService();

  Timer? _callTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isEndingCall = false;

  // Track participant info: participantId -> {name, photoUrl}
  final Map<String, Map<String, dynamic>> _participantInfo = {};

  // Track which participants have active video
  final Map<String, bool> _participantVideoStatus = {};

  @override
  void initState() {
    super.initState();
    debugPrint('  GroupVideoCallScreen: initState - callId=${widget.callId}');

    // Store participant info
    for (var participant in widget.participants) {
      if (participant['userId'] != widget.userId) {
        _participantInfo[participant['userId']] = {
          'name': participant['name'] ?? 'Unknown',
          'photoUrl': participant['photoUrl'],
        };
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeCall();
    });
  }

  void _initializeCall() {
    _setupGroupVideoService();
    _joinCall();
    _startCallTimer();
  }

  void _setupGroupVideoService() {
    _groupVideoService.onParticipantJoined = (participantId, participantName) {
      if (mounted) {
        debugPrint('  GroupVideoCallScreen: Participant joined: $participantName');
        setState(() {
          _participantVideoStatus[participantId] = false;
        });
      }
    };

    _groupVideoService.onParticipantLeft = (participantId) {
      if (mounted) {
        debugPrint('  GroupVideoCallScreen: Participant left: $participantId');
        setState(() {
          _participantVideoStatus.remove(participantId);
        });
      }
    };

    _groupVideoService.onRemoteStreamReady = (participantId) {
      if (mounted) {
        debugPrint('  GroupVideoCallScreen: Remote stream ready for $participantId');
        setState(() {
          _participantVideoStatus[participantId] = true;
        });
      }
    };

    _groupVideoService.onLocalStreamReady = () {
      if (mounted) {
        debugPrint('  GroupVideoCallScreen: Local stream ready');
        setState(() {});
      }
    };

    _groupVideoService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };
  }

  void _joinCall() {
    _groupVideoService.joinGroupCall(widget.callId, widget.userId).then((success) {
      if (!success && mounted) {
        _endCall();
      }
    });
  }

  void _startCallTimer() {
    // Timer runs but only increments when at least one other participant has joined
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Only increment if there are other active participants
        if (_participantVideoStatus.isNotEmpty) {
          setState(() {
            _callDuration++;
          });
        }
      }
    });
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    debugPrint('  GroupVideoCallScreen: Ending call...');

    if (mounted) {
      Navigator.of(context).pop();
    }

    _callTimer?.cancel();

    try {
      // Update call status
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('  GroupVideoCallScreen: Error updating call status: $e');
    }

    await _groupVideoService.leaveCall();
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    await _groupVideoService.toggleMute();
  }

  Future<void> _toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    await _groupVideoService.toggleSpeaker();
  }

  Future<void> _toggleVideo() async {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    await _groupVideoService.toggleVideo();
  }

  Future<void> _switchCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    await _groupVideoService.switchCamera();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _groupVideoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalParticipants = _groupVideoService.participantCount;
    final remoteRenderers = _groupVideoService.remoteRenderers;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Grid layout for video feeds (WhatsApp style)
            Positioned.fill(
              child: _buildVideoGrid(totalParticipants, remoteRenderers),
            ),

            // Top overlay with call info
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
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Group Video Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDuration(_callDuration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalParticipants ${totalParticipants == 1 ? "participant" : "participants"}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom controls
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Control buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                            onPressed: _toggleVideo,
                            isActive: _isVideoEnabled,
                          ),
                          _buildControlButton(
                            icon: Icons.flip_camera_android,
                            onPressed: _switchCamera,
                            isActive: true,
                          ),
                          _buildControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            onPressed: _toggleMute,
                            isActive: !_isMuted,
                          ),
                          _buildControlButton(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            onPressed: _toggleSpeaker,
                            isActive: _isSpeakerOn,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // End call button
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
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

  /// Build video grid layout (WhatsApp style)
  Widget _buildVideoGrid(int participantCount, Map<String, RTCVideoRenderer> remoteRenderers) {
    // Create list of all video tiles (local + remote)
    final List<Widget> videoTiles = [];

    // Add local video
    videoTiles.add(_buildLocalVideoTile());

    // Add remote videos
    for (var entry in remoteRenderers.entries) {
      final participantId = entry.key;
      final renderer = entry.value;
      final hasVideo = _participantVideoStatus[participantId] ?? false;
      final info = _participantInfo[participantId];

      videoTiles.add(_buildRemoteVideoTile(
        renderer: renderer,
        participantId: participantId,
        participantName: info?['name'] ?? 'Unknown',
        participantPhotoUrl: info?['photoUrl'],
        hasVideo: hasVideo,
      ));
    }

    // Determine grid layout based on participant count
    if (participantCount == 1) {
      // Full screen
      return videoTiles[0];
    } else if (participantCount == 2) {
      // 2 participants: vertical split
      return Column(
        children: [
          Expanded(child: videoTiles[0]),
          Expanded(child: videoTiles[1]),
        ],
      );
    } else if (participantCount <= 4) {
      // 3-4 participants: 2x2 grid
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
        ),
        itemCount: videoTiles.length,
        itemBuilder: (context, index) => videoTiles[index],
      );
    } else if (participantCount <= 6) {
      // 5-6 participants: 2x3 grid
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
        ),
        itemCount: videoTiles.length,
        itemBuilder: (context, index) => videoTiles[index],
      );
    } else {
      // 7-8 participants: 2x4 grid (scrollable if needed)
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
        ),
        itemCount: videoTiles.length,
        itemBuilder: (context, index) => videoTiles[index],
      );
    }
  }

  /// Build local video tile
  Widget _buildLocalVideoTile() {
    final hasLocalVideo = _groupVideoService.localRenderer.srcObject != null;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        children: [
          // Video or avatar
          if (hasLocalVideo && _isVideoEnabled)
            Positioned.fill(
              child: RTCVideoView(
                _groupVideoService.localRenderer,
                mirror: _isFrontCamera,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Center(
              child: SafeCircleAvatar(
                photoUrl: null,
                radius: 40,
                name: widget.userName,
              ),
            ),

          // Name label
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'You',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Mute indicator
          if (_isMuted)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_off,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build remote video tile
  Widget _buildRemoteVideoTile({
    required RTCVideoRenderer renderer,
    required String participantId,
    required String participantName,
    String? participantPhotoUrl,
    required bool hasVideo,
  }) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Stack(
        children: [
          // Video or avatar
          if (hasVideo)
            Positioned.fill(
              child: RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: false,
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SafeCircleAvatar(
                    photoUrl: participantPhotoUrl,
                    radius: 40,
                    name: participantName,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    participantName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Name label
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participantName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Control button widget
  Widget _buildControlButton({
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
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
