import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

/// Group Video Call Service using WebRTC with SFU architecture
/// Supports SingleTap-style group video calls with multiple participants
class GroupVideoCallService {
  static final GroupVideoCallService _instance =
      GroupVideoCallService._internal();
  factory GroupVideoCallService() => _instance;
  GroupVideoCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local stream and renderer
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  // Map of participant connections: participantId -> RTCPeerConnection
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Map of remote streams: participantId -> MediaStream
  final Map<String, MediaStream> _remoteStreams = {};

  // Map of remote renderers: participantId -> RTCVideoRenderer
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  String? _currentCallId;
  String? _currentUserId;
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  bool _isSpeakerOn = true;
  bool _isRequestingPermissions = false;

  // Subscription listeners
  StreamSubscription? _participantsSubscription;
  final Map<String, StreamSubscription> _offerSubscriptions = {};
  final Map<String, StreamSubscription> _answerSubscriptions = {};
  final Map<String, StreamSubscription> _iceCandidateSubscriptions = {};

  // Pending ICE candidates per participant
  final Map<String, List<RTCIceCandidate>> _pendingIceCandidates = {};

  // Callbacks
  Function(String participantId, String participantName)? onParticipantJoined;
  Function(String participantId)? onParticipantLeft;
  Function(String message)? onError;
  Function()? onJoinChannelSuccess;
  Function()? onLeaveChannel;
  Function(String participantId)? onRemoteStreamReady;
  Function()? onLocalStreamReady;

  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      // Free TURN servers
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  RTCVideoRenderer get localRenderer => _localRenderer;
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  int get participantCount => _remoteStreams.length + 1; // +1 for self

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('  GroupVideoCallService: Already initialized');
      return true;
    }

    if (_isRequestingPermissions) {
      debugPrint(
        '  GroupVideoCallService: Permission request in progress, waiting...',
      );
      while (_isRequestingPermissions) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_isInitialized) return true;
    }

    try {
      _isRequestingPermissions = true;
      debugPrint('  GroupVideoCallService: Requesting permissions...');

      final micStatus = await Permission.microphone.status;
      final cameraStatus = await Permission.camera.status;

      PermissionStatus micPermission = micStatus;
      PermissionStatus cameraPermission = cameraStatus;

      if (!micStatus.isGranted) {
        micPermission = await Permission.microphone.request();
      }
      if (!cameraStatus.isGranted) {
        cameraPermission = await Permission.camera.request();
      }

      _isRequestingPermissions = false;

      if (!micPermission.isGranted || !cameraPermission.isGranted) {
        debugPrint('  GroupVideoCallService: Permissions denied');
        onError?.call('Camera and microphone permissions are required');
        return false;
      }

      // Initialize local renderer
      if (_localRenderer.textureId == null) {
        await _localRenderer.initialize();
        debugPrint('  GroupVideoCallService:    Local renderer initialized');
      }

      _isInitialized = true;
      debugPrint('  GroupVideoCallService:   Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _isRequestingPermissions = false;
      debugPrint('  GroupVideoCallService:   Initialization error - $e');
      debugPrint('  GroupVideoCallService: Stack trace: $stackTrace');
      onError?.call('Failed to initialize: $e');
      return false;
    }
  }

  /// Join a group video call
  Future<bool> joinGroupCall(String callId, String userId) async {
    debugPrint(
      '  GroupVideoCallService: Joining group call $callId as user $userId',
    );

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    try {
      _currentCallId = callId;
      _currentUserId = userId;

      // Get local stream first
      await _getLocalStream();

      // Add self to participants list
      await _firestore
          .collection('group_calls')
          .doc(callId)
          .collection('participants')
          .doc(userId)
          .set({
            'userId': userId,
            'joinedAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });

      _isInCall = true;

      // Listen for other participants
      _listenForParticipants(callId, userId);

      onJoinChannelSuccess?.call();
      debugPrint('  GroupVideoCallService:   Joined group call successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('  GroupVideoCallService:   Error joining call - $e');
      debugPrint('  GroupVideoCallService: Stack trace: $stackTrace');
      onError?.call('Failed to join call: $e');
      return false;
    }
  }

  /// Get local video/audio stream
  Future<void> _getLocalStream() async {
    debugPrint('  GroupVideoCallService: Getting local stream...');

    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': {
        'facingMode': _isFrontCamera ? 'user' : 'environment',
        'width': {'ideal': 1280, 'min': 640},
        'height': {'ideal': 720, 'min': 480},
        'frameRate': {'ideal': 30, 'min': 15},
      },
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (_localStream == null) {
        throw Exception('Failed to get media stream');
      }

      // Enable tracks
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = _isVideoEnabled;
      }
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }

      // Assign to renderer
      _localRenderer.srcObject = _localStream;

      // Enable speaker
      try {
        await Helper.setSpeakerphoneOn(true);
        _isSpeakerOn = true;
      } catch (e) {
        debugPrint('  GroupVideoCallService: Could not set speaker: $e');
      }

      onLocalStreamReady?.call();
      debugPrint('  GroupVideoCallService:   Local stream ready');
    } catch (e, stackTrace) {
      debugPrint('  GroupVideoCallService:   Error getting local stream - $e');
      debugPrint('  GroupVideoCallService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Listen for participants joining/leaving
  void _listenForParticipants(String callId, String userId) {
    debugPrint('  GroupVideoCallService: Listening for participants...');

    _participantsSubscription = _firestore
        .collection('group_calls')
        .doc(callId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) async {
            for (var change in snapshot.docChanges) {
              final participantId = change.doc.id;

              // Skip self
              if (participantId == userId) continue;

              if (change.type == DocumentChangeType.added) {
                debugPrint(
                  '  GroupVideoCallService: Participant joined: $participantId',
                );
                final data = change.doc.data() as Map<String, dynamic>;
                final participantName = data['userName'] ?? 'Unknown';

                // Create peer connection for this participant
                await _createPeerConnectionForParticipant(participantId);

                // Create offer to the new participant
                await _createOffer(participantId);

                onParticipantJoined?.call(participantId, participantName);
              } else if (change.type == DocumentChangeType.removed ||
                  (change.doc.data()?['isActive'] == false)) {
                debugPrint(
                  '  GroupVideoCallService: Participant left: $participantId',
                );
                await _removeParticipant(participantId);
                onParticipantLeft?.call(participantId);
              }
            }
          },
          onError: (e) {
            debugPrint(
              '  GroupVideoCallService: Error listening for participants: $e',
            );
          },
        );
  }

  /// Create peer connection for a participant
  Future<void> _createPeerConnectionForParticipant(String participantId) async {
    debugPrint(
      '  GroupVideoCallService: Creating peer connection for $participantId',
    );

    try {
      final peerConnection = await createPeerConnection(_configuration);

      // Add local tracks
      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          await peerConnection.addTrack(track, _localStream!);
        }
        for (var track in _localStream!.getVideoTracks()) {
          await peerConnection.addTrack(track, _localStream!);
        }
      }

      // Handle ICE candidates
      peerConnection.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          _sendIceCandidate(participantId, candidate);
        }
      };

      // Handle remote tracks
      peerConnection.onTrack = (event) async {
        debugPrint(
          '  GroupVideoCallService: Remote track received from $participantId',
        );

        if (event.streams.isNotEmpty) {
          _remoteStreams[participantId] = event.streams[0];

          // Create renderer for this participant if not exists
          if (!_remoteRenderers.containsKey(participantId)) {
            final renderer = RTCVideoRenderer();
            await renderer.initialize();
            _remoteRenderers[participantId] = renderer;
          }

          // Enable tracks
          for (var track in event.streams[0].getVideoTracks()) {
            track.enabled = true;
          }
          for (var track in event.streams[0].getAudioTracks()) {
            track.enabled = true;
          }

          // Assign stream to renderer
          _remoteRenderers[participantId]?.srcObject = event.streams[0];

          onRemoteStreamReady?.call(participantId);
          debugPrint(
            '  GroupVideoCallService:   Remote stream ready for $participantId',
          );
        }
      };

      // Handle connection state
      peerConnection.onIceConnectionState = (state) {
        debugPrint(
          '  GroupVideoCallService: ICE state for $participantId: $state',
        );
      };

      _peerConnections[participantId] = peerConnection;

      // Listen for signaling from this participant
      _listenForSignaling(participantId);
      _listenForIceCandidates(participantId);

      debugPrint(
        '  GroupVideoCallService:   Peer connection created for $participantId',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '  GroupVideoCallService:   Error creating peer connection: $e',
      );
      debugPrint('  GroupVideoCallService: Stack trace: $stackTrace');
    }
  }

  /// Create and send offer to a participant
  Future<void> _createOffer(String participantId) async {
    debugPrint('  GroupVideoCallService: Creating offer for $participantId');

    try {
      final peerConnection = _peerConnections[participantId];
      if (peerConnection == null) return;

      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      // Send offer to Firestore
      await _firestore
          .collection('group_calls')
          .doc(_currentCallId)
          .collection('signaling')
          .doc('${_currentUserId}_to_$participantId')
          .set({
            'from': _currentUserId,
            'to': participantId,
            'type': 'offer',
            'sdp': offer.sdp,
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('  GroupVideoCallService:   Offer sent to $participantId');
    } catch (e) {
      debugPrint('  GroupVideoCallService:   Error creating offer: $e');
    }
  }

  /// Listen for signaling messages from a participant
  void _listenForSignaling(String participantId) {
    // Listen for offers from this participant
    _offerSubscriptions[participantId] = _firestore
        .collection('group_calls')
        .doc(_currentCallId)
        .collection('signaling')
        .where('from', isEqualTo: participantId)
        .where('to', isEqualTo: _currentUserId)
        .where('type', isEqualTo: 'offer')
        .snapshots()
        .listen((snapshot) async {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final sdp = data['sdp'] as String?;

            if (sdp != null) {
              await _handleOffer(participantId, sdp);

              // Delete processed offer
              await doc.reference.delete();
            }
          }
        });

    // Listen for answers from this participant
    _answerSubscriptions[participantId] = _firestore
        .collection('group_calls')
        .doc(_currentCallId)
        .collection('signaling')
        .where('from', isEqualTo: participantId)
        .where('to', isEqualTo: _currentUserId)
        .where('type', isEqualTo: 'answer')
        .snapshots()
        .listen((snapshot) async {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final sdp = data['sdp'] as String?;

            if (sdp != null) {
              await _handleAnswer(participantId, sdp);

              // Delete processed answer
              await doc.reference.delete();
            }
          }
        });
  }

  /// Handle received offer from a participant
  Future<void> _handleOffer(String participantId, String sdp) async {
    debugPrint('  GroupVideoCallService: Handling offer from $participantId');

    try {
      final peerConnection = _peerConnections[participantId];
      if (peerConnection == null) {
        // Create peer connection if it doesn't exist
        await _createPeerConnectionForParticipant(participantId);
      }

      final pc = _peerConnections[participantId];
      if (pc == null) return;

      final offer = RTCSessionDescription(sdp, 'offer');
      await pc.setRemoteDescription(offer);

      // Process pending ICE candidates
      final pendingCandidates = _pendingIceCandidates[participantId] ?? [];
      for (var candidate in pendingCandidates) {
        await pc.addCandidate(candidate);
      }
      _pendingIceCandidates[participantId]?.clear();

      // Create answer
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      // Send answer
      await _firestore
          .collection('group_calls')
          .doc(_currentCallId)
          .collection('signaling')
          .doc('${_currentUserId}_to_$participantId')
          .set({
            'from': _currentUserId,
            'to': participantId,
            'type': 'answer',
            'sdp': answer.sdp,
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('  GroupVideoCallService:   Answer sent to $participantId');
    } catch (e) {
      debugPrint('  GroupVideoCallService:   Error handling offer: $e');
    }
  }

  /// Handle received answer from a participant
  Future<void> _handleAnswer(String participantId, String sdp) async {
    debugPrint('  GroupVideoCallService: Handling answer from $participantId');

    try {
      final peerConnection = _peerConnections[participantId];
      if (peerConnection == null) return;

      final answer = RTCSessionDescription(sdp, 'answer');
      await peerConnection.setRemoteDescription(answer);

      // Process pending ICE candidates
      final pendingCandidates = _pendingIceCandidates[participantId] ?? [];
      for (var candidate in pendingCandidates) {
        await peerConnection.addCandidate(candidate);
      }
      _pendingIceCandidates[participantId]?.clear();

      debugPrint(
        '  GroupVideoCallService:   Answer processed from $participantId',
      );
    } catch (e) {
      debugPrint('  GroupVideoCallService:   Error handling answer: $e');
    }
  }

  /// Send ICE candidate to a participant
  Future<void> _sendIceCandidate(
    String participantId,
    RTCIceCandidate candidate,
  ) async {
    try {
      await _firestore
          .collection('group_calls')
          .doc(_currentCallId)
          .collection('ice_candidates')
          .add({
            'from': _currentUserId,
            'to': participantId,
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('  GroupVideoCallService: Error sending ICE candidate: $e');
    }
  }

  /// Listen for ICE candidates from a participant
  void _listenForIceCandidates(String participantId) {
    _iceCandidateSubscriptions[participantId] = _firestore
        .collection('group_calls')
        .doc(_currentCallId)
        .collection('ice_candidates')
        .where('from', isEqualTo: participantId)
        .where('to', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) async {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final candidateStr = data['candidate'];
            final sdpMid = data['sdpMid'];
            final sdpMLineIndex = data['sdpMLineIndex'];

            if (candidateStr != null) {
              final candidate = RTCIceCandidate(
                candidateStr,
                sdpMid,
                sdpMLineIndex,
              );

              final peerConnection = _peerConnections[participantId];
              if (peerConnection != null &&
                  peerConnection.signalingState ==
                      RTCSignalingState.RTCSignalingStateStable) {
                await peerConnection.addCandidate(candidate);
              } else {
                // Queue candidate for later
                _pendingIceCandidates
                    .putIfAbsent(participantId, () => [])
                    .add(candidate);
              }

              // Delete processed candidate
              await doc.reference.delete();
            }
          }
        });
  }

  /// Remove a participant
  Future<void> _removeParticipant(String participantId) async {
    debugPrint('  GroupVideoCallService: Removing participant $participantId');

    // Close peer connection
    await _peerConnections[participantId]?.close();
    _peerConnections.remove(participantId);

    // Dispose renderer
    await _remoteRenderers[participantId]?.dispose();
    _remoteRenderers.remove(participantId);

    // Remove stream
    _remoteStreams.remove(participantId);

    // Cancel subscriptions
    await _offerSubscriptions[participantId]?.cancel();
    await _answerSubscriptions[participantId]?.cancel();
    await _iceCandidateSubscriptions[participantId]?.cancel();
    _offerSubscriptions.remove(participantId);
    _answerSubscriptions.remove(participantId);
    _iceCandidateSubscriptions.remove(participantId);

    // Clear pending ICE candidates
    _pendingIceCandidates.remove(participantId);

    debugPrint(
      '  GroupVideoCallService:   Participant removed: $participantId',
    );
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
    debugPrint('  GroupVideoCallService: Mute: $_isMuted');
  }

  /// Toggle video
  Future<void> toggleVideo() async {
    _isVideoEnabled = !_isVideoEnabled;
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = _isVideoEnabled;
      }
    }
    debugPrint('  GroupVideoCallService: Video: $_isVideoEnabled');
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
    } catch (e) {
      debugPrint('  GroupVideoCallService: Toggle speaker error: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    debugPrint('  GroupVideoCallService: Switching camera...');
    _isFrontCamera = !_isFrontCamera;

    if (_localStream == null) return;

    try {
      // Get all senders
      final senders = <RTCRtpSender>[];
      for (var pc in _peerConnections.values) {
        senders.addAll(await pc.getSenders());
      }

      // Stop current video tracks
      for (var track in _localStream!.getVideoTracks()) {
        await track.stop();
      }

      // Get new stream with opposite camera
      final mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'width': {'ideal': 1280, 'min': 640},
          'height': {'ideal': 720, 'min': 480},
        },
      };

      final newStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      final newVideoTrack = newStream.getVideoTracks().first;
      newVideoTrack.enabled = _isVideoEnabled;

      // Replace video track in all peer connections
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(newVideoTrack);
        }
      }

      // Update local stream
      final audioTracks = _localStream!.getAudioTracks();
      _localStream = newStream;
      for (var audioTrack in audioTracks) {
        _localStream!.addTrack(audioTrack);
      }

      // Update renderer
      _localRenderer.srcObject = _localStream;

      debugPrint('  GroupVideoCallService:   Camera switched');
    } catch (e) {
      debugPrint('  GroupVideoCallService:   Error switching camera: $e');
      _isFrontCamera = !_isFrontCamera;
    }
  }

  /// Leave the call
  Future<void> leaveCall() async {
    debugPrint('  GroupVideoCallService: Leaving call...');

    // Mark self as inactive
    if (_currentCallId != null && _currentUserId != null) {
      try {
        await _firestore
            .collection('group_calls')
            .doc(_currentCallId)
            .collection('participants')
            .doc(_currentUserId)
            .update({'isActive': false});
      } catch (e) {
        debugPrint(
          '  GroupVideoCallService: Error updating participant status: $e',
        );
      }
    }

    // Cancel all subscriptions
    await _participantsSubscription?.cancel();
    for (var sub in _offerSubscriptions.values) {
      await sub.cancel();
    }
    for (var sub in _answerSubscriptions.values) {
      await sub.cancel();
    }
    for (var sub in _iceCandidateSubscriptions.values) {
      await sub.cancel();
    }

    // Close all peer connections
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    // Dispose all renderers
    for (var renderer in _remoteRenderers.values) {
      await renderer.dispose();
    }
    _remoteRenderers.clear();

    // Dispose streams
    _remoteStreams.clear();

    // Stop local stream
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      for (var track in _localStream!.getVideoTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    _localRenderer.srcObject = null;

    // Reset state
    _isInCall = false;
    _isMuted = false;
    _isVideoEnabled = true;
    _currentCallId = null;
    _currentUserId = null;

    onLeaveChannel?.call();
    debugPrint('  GroupVideoCallService:   Left call');
  }

  /// Dispose the service
  Future<void> dispose() async {
    await leaveCall();
  }
}
