import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

/// Group Voice Call Service using WebRTC with Mesh Architecture
/// Each participant maintains peer connections with all other participants
class GroupVoiceCallService {
  static final GroupVoiceCallService _instance =
      GroupVoiceCallService._internal();
  factory GroupVoiceCallService() => _instance;
  GroupVoiceCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Maps participantId -> RTCPeerConnection
  final Map<String, RTCPeerConnection> _peerConnections = {};

  MediaStream? _localStream;

  // Maps participantId -> MediaStream
  final Map<String, MediaStream> _remoteStreams = {};

  String? _currentCallId;
  String? _currentUserId;
  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // Maps participantId -> whether remote description is set
  final Map<String, bool> _remoteDescriptionSet = {};

  // Maps participantId -> pending ICE candidates
  final Map<String, List<RTCIceCandidate>> _pendingIceCandidates = {};

  // Firestore listeners
  final Map<String, StreamSubscription> _participantListeners = {};
  StreamSubscription? _callStatusListener;

  // Callbacks
  Function(String participantId, String participantName)? onParticipantJoined;
  Function(String participantId)? onParticipantLeft;
  Function(String message)? onError;

  // WebRTC configuration with STUN and TURN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
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

  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('GroupVoiceCallService: Already initialized');
      return true;
    }

    try {
      debugPrint('GroupVoiceCallService: Requesting microphone permission...');
      final micPermission = await Permission.microphone.request();

      if (!micPermission.isGranted) {
        debugPrint('GroupVoiceCallService: Microphone permission denied');
        return false;
      }

      _isInitialized = true;
      debugPrint('GroupVoiceCallService:   Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('GroupVoiceCallService:   Initialization error - $e');
      return false;
    }
  }

  /// Get local audio stream
  Future<void> _getLocalStream() async {
    debugPrint('GroupVoiceCallService: Getting local audio stream...');

    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint('GroupVoiceCallService:   Local audio stream obtained');

    // Enable speaker by default
    try {
      await Helper.setSpeakerphoneOn(true);
      _isSpeakerOn = true;
      debugPrint('GroupVoiceCallService: Speaker enabled');
    } catch (e) {
      debugPrint('GroupVoiceCallService: Could not set speaker: $e');
    }
  }

  /// Create peer connection for a specific participant
  Future<RTCPeerConnection> _createPeerConnection(String participantId) async {
    debugPrint(
      'GroupVoiceCallService: Creating peer connection for $participantId',
    );

    final pc = await createPeerConnection(_configuration);
    _remoteDescriptionSet[participantId] = false;
    _pendingIceCandidates[participantId] = [];

    // Add local audio tracks
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _sendIceCandidate(participantId, candidate);
      }
    };

    // Handle ICE connection state
    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('GroupVoiceCallService: ICE state for $participantId: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        debugPrint('GroupVoiceCallService:   Connected to $participantId');
      }
    };

    // Handle remote audio track
    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        _remoteStreams[participantId] = event.streams[0];
        debugPrint(
          'GroupVoiceCallService:   Receiving audio from $participantId',
        );

        // Enable audio track
        for (var track in event.streams[0].getAudioTracks()) {
          track.enabled = true;
        }
      }
    };

    // Also handle onAddStream for compatibility
    pc.onAddStream = (MediaStream stream) {
      _remoteStreams[participantId] = stream;
      for (var track in stream.getAudioTracks()) {
        track.enabled = true;
      }
    };

    _peerConnections[participantId] = pc;
    debugPrint(
      'GroupVoiceCallService:   Peer connection created for $participantId',
    );

    return pc;
  }

  /// Join a group call
  Future<bool> joinCall(String callId, String userId) async {
    debugPrint(
      'GroupVoiceCallService: ========================================',
    );
    debugPrint(
      'GroupVoiceCallService: Joining group call $callId as user $userId',
    );

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    try {
      _currentCallId = callId;
      _currentUserId = userId;

      // Get local audio stream
      await _getLocalStream();

      // Mark self as active in Firestore
      await _firestore
          .collection('group_calls')
          .doc(callId)
          .collection('participants')
          .doc(userId)
          .update({'isActive': true, 'joinedAt': FieldValue.serverTimestamp()});

      _isInCall = true;

      // Listen for other participants
      _listenForParticipants();

      debugPrint('GroupVoiceCallService:   Joined group call successfully');
      return true;
    } catch (e) {
      debugPrint('GroupVoiceCallService:   Join call error - $e');
      onError?.call('Failed to join call: $e');
      return false;
    }
  }

  /// Listen for participants joining/leaving
  void _listenForParticipants() {
    if (_currentCallId == null || _currentUserId == null) return;

    debugPrint('GroupVoiceCallService: Starting participant listener...');

    _callStatusListener = _firestore
        .collection('group_calls')
        .doc(_currentCallId!)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            final participantId = change.doc.id;

            // Skip self
            if (participantId == _currentUserId) continue;

            if (change.type == DocumentChangeType.added) {
              // New participant joined
              debugPrint(
                'GroupVoiceCallService:   Participant $participantId joined',
              );
              await _connectToParticipant(participantId);

              final participantData = change.doc.data();
              final participantName = participantData?['name'] ?? 'Unknown';
              onParticipantJoined?.call(participantId, participantName);
            } else if (change.type == DocumentChangeType.removed ||
                change.doc.data()?['isActive'] == false) {
              // Participant left
              debugPrint(
                'GroupVoiceCallService:   Participant $participantId left',
              );
              await _disconnectFromParticipant(participantId);
              onParticipantLeft?.call(participantId);
            }
          }
        });
  }

  /// Connect to a specific participant
  Future<void> _connectToParticipant(String participantId) async {
    debugPrint('GroupVoiceCallService: Connecting to $participantId');

    // Create peer connection
    final pc = await _createPeerConnection(participantId);

    // Determine who initiates (lexicographic order of user IDs)
    final shouldInitiate = _currentUserId!.compareTo(participantId) < 0;

    if (shouldInitiate) {
      // We initiate - create offer
      debugPrint('GroupVoiceCallService: Creating offer for $participantId');
      await _createOffer(participantId, pc);
    } else {
      // They initiate - wait for offer
      debugPrint(
        'GroupVoiceCallService: Waiting for offer from $participantId',
      );
    }

    // Listen for signaling from this participant
    _listenForSignaling(participantId);
  }

  /// Disconnect from a participant
  Future<void> _disconnectFromParticipant(String participantId) async {
    debugPrint('GroupVoiceCallService: Disconnecting from $participantId');

    // Cancel listener
    _participantListeners[participantId]?.cancel();
    _participantListeners.remove(participantId);

    // Close peer connection
    await _peerConnections[participantId]?.close();
    _peerConnections.remove(participantId);

    // Remove remote stream
    _remoteStreams.remove(participantId);

    // Clean up state
    _remoteDescriptionSet.remove(participantId);
    _pendingIceCandidates.remove(participantId);
  }

  /// Create and send offer to a participant
  Future<void> _createOffer(String participantId, RTCPeerConnection pc) async {
    try {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await pc.setLocalDescription(offer);

      // Send offer via Firestore
      await _firestore
          .collection('group_calls')
          .doc(_currentCallId)
          .collection('signaling')
          .doc('${_currentUserId}_to_$participantId')
          .set({
            'from': _currentUserId,
            'to': participantId,
            'offer': {'sdp': offer.sdp, 'type': offer.type},
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('GroupVoiceCallService:   Offer sent to $participantId');
    } catch (e) {
      debugPrint(
        'GroupVoiceCallService:   Create offer error for $participantId - $e',
      );
    }
  }

  /// Handle received offer and create answer
  Future<void> _handleOffer(
    String participantId,
    Map<String, dynamic> offerData,
  ) async {
    try {
      final pc = _peerConnections[participantId];
      if (pc == null) {
        debugPrint(
          'GroupVoiceCallService: No peer connection for $participantId, creating one',
        );
        await _createPeerConnection(participantId);
        return _handleOffer(participantId, offerData);
      }

      final offer = RTCSessionDescription(
        offerData['sdp'] as String,
        offerData['type'] as String,
      );

      await pc.setRemoteDescription(offer);
      _remoteDescriptionSet[participantId] = true;

      // Process pending ICE candidates
      await _processPendingIceCandidates(participantId);

      // Create answer
      final answer = await pc.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      await pc.setLocalDescription(answer);

      // Send answer via Firestore
      await _firestore
          .collection('group_calls')
          .doc(_currentCallId)
          .collection('signaling')
          .doc('${_currentUserId}_to_$participantId')
          .set({
            'from': _currentUserId,
            'to': participantId,
            'answer': {'sdp': answer.sdp, 'type': answer.type},
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('GroupVoiceCallService:   Answer sent to $participantId');
    } catch (e) {
      debugPrint(
        'GroupVoiceCallService:   Handle offer error for $participantId - $e',
      );
    }
  }

  /// Handle received answer
  Future<void> _handleAnswer(
    String participantId,
    Map<String, dynamic> answerData,
  ) async {
    try {
      final pc = _peerConnections[participantId];
      if (pc == null) return;

      final answer = RTCSessionDescription(
        answerData['sdp'] as String,
        answerData['type'] as String,
      );

      await pc.setRemoteDescription(answer);
      _remoteDescriptionSet[participantId] = true;

      // Process pending ICE candidates
      await _processPendingIceCandidates(participantId);

      debugPrint(
        'GroupVoiceCallService:   Answer received from $participantId',
      );
    } catch (e) {
      debugPrint(
        'GroupVoiceCallService:   Handle answer error for $participantId - $e',
      );
    }
  }

  /// Listen for signaling messages from a specific participant
  void _listenForSignaling(String participantId) {
    // Listen for messages TO us FROM this participant
    final sub = _firestore
        .collection('group_calls')
        .doc(_currentCallId)
        .collection('signaling')
        .doc('${participantId}_to_$_currentUserId')
        .snapshots()
        .listen((snapshot) async {
          final data = snapshot.data();
          if (data == null) return;

          // Handle offer
          if (data['offer'] != null) {
            debugPrint(
              'GroupVoiceCallService: 📥 Received offer from $participantId',
            );
            await _handleOffer(
              participantId,
              Map<String, dynamic>.from(data['offer']),
            );
          }

          // Handle answer
          if (data['answer'] != null) {
            debugPrint(
              'GroupVoiceCallService: 📥 Received answer from $participantId',
            );
            await _handleAnswer(
              participantId,
              Map<String, dynamic>.from(data['answer']),
            );
          }
        });

    _participantListeners[participantId] = sub;

    // Also listen for ICE candidates
    _listenForIceCandidates(participantId);
  }

  /// Send ICE candidate to a participant
  Future<void> _sendIceCandidate(
    String participantId,
    RTCIceCandidate candidate,
  ) async {
    if (_currentCallId == null || _currentUserId == null) return;

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
      debugPrint('GroupVoiceCallService: Send ICE candidate error - $e');
    }
  }

  /// Listen for ICE candidates from a specific participant
  void _listenForIceCandidates(String participantId) {
    final sub = _firestore
        .collection('group_calls')
        .doc(_currentCallId)
        .collection('ice_candidates')
        .where('from', isEqualTo: participantId)
        .where('to', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null && data['candidate'] != null) {
                try {
                  int? mLineIndexInt;
                  final sdpMLineIndexValue = data['sdpMLineIndex'];

                  if (sdpMLineIndexValue is int) {
                    mLineIndexInt = sdpMLineIndexValue;
                  } else if (sdpMLineIndexValue is String) {
                    mLineIndexInt = int.tryParse(sdpMLineIndexValue);
                  }

                  final candidate = RTCIceCandidate(
                    data['candidate'],
                    data['sdpMid'],
                    mLineIndexInt,
                  );

                  final pc = _peerConnections[participantId];
                  if (pc != null &&
                      _remoteDescriptionSet[participantId] == true) {
                    await pc.addCandidate(candidate);
                    debugPrint(
                      'GroupVoiceCallService:   Added ICE candidate from $participantId',
                    );
                  } else {
                    // Queue for later
                    _pendingIceCandidates[participantId]?.add(candidate);
                    debugPrint(
                      'GroupVoiceCallService: Queued ICE candidate from $participantId',
                    );
                  }
                } catch (e) {
                  debugPrint(
                    'GroupVoiceCallService: Error processing ICE candidate: $e',
                  );
                }
              }
            }
          }
        });

    _participantListeners['ice_$participantId'] = sub;
  }

  /// Process pending ICE candidates for a participant
  Future<void> _processPendingIceCandidates(String participantId) async {
    final pending = _pendingIceCandidates[participantId];
    if (pending == null || pending.isEmpty) return;

    debugPrint(
      'GroupVoiceCallService: Processing ${pending.length} pending ICE candidates for $participantId',
    );

    final pc = _peerConnections[participantId];
    if (pc == null) return;

    for (var candidate in pending) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('GroupVoiceCallService: Error adding pending candidate: $e');
      }
    }

    pending.clear();
  }

  /// Leave the group call
  Future<void> leaveCall() async {
    debugPrint('GroupVoiceCallService: Leaving call...');

    // Mark self as inactive
    if (_currentCallId != null && _currentUserId != null) {
      try {
        await _firestore
            .collection('group_calls')
            .doc(_currentCallId)
            .collection('participants')
            .doc(_currentUserId)
            .update({
              'isActive': false,
              'leftAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint(
          'GroupVoiceCallService: Error updating participant status: $e',
        );
      }
    }

    // Cancel all listeners
    for (var sub in _participantListeners.values) {
      await sub.cancel();
    }
    _participantListeners.clear();

    _callStatusListener?.cancel();
    _callStatusListener = null;

    // Close all peer connections
    for (var pc in _peerConnections.values) {
      try {
        await pc.close();
      } catch (e) {
        debugPrint('GroupVoiceCallService: Error closing peer connection: $e');
      }
    }
    _peerConnections.clear();

    // Stop and dispose local stream
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // Clear remote streams
    _remoteStreams.clear();
    _remoteDescriptionSet.clear();
    _pendingIceCandidates.clear();

    _currentCallId = null;
    _currentUserId = null;
    _isInCall = false;
    _isMuted = false;

    debugPrint('GroupVoiceCallService:   Left call successfully');
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
    debugPrint('GroupVoiceCallService: Mute: $_isMuted');
  }

  /// Set mute state
  Future<void> setMute(bool muted) async {
    if (_localStream == null) return;

    _isMuted = muted;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
    debugPrint('GroupVoiceCallService: Mute set to $muted');
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      debugPrint('GroupVoiceCallService: Speaker: $_isSpeakerOn');
    } catch (e) {
      debugPrint('GroupVoiceCallService: Toggle speaker error - $e');
    }
  }

  /// Set speaker state
  Future<void> setSpeaker(bool enabled) async {
    _isSpeakerOn = enabled;
    try {
      await Helper.setSpeakerphoneOn(enabled);
      debugPrint('GroupVoiceCallService: Speaker set to $enabled');
    } catch (e) {
      debugPrint('GroupVoiceCallService: Set speaker error - $e');
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    debugPrint('GroupVoiceCallService: Disposing');
    await leaveCall();
    _isInitialized = false;
  }
}
