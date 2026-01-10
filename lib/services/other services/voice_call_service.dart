import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice Call Service using WebRTC via Firebase Signaling
/// Works on all Android devices (API 21+)
class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;
  bool _isCaller = false;
  bool _offerHandled = false;
  bool _answerHandled = false;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _iceCandidateSubscription;

  // Queue for ICE candidates received before remote description is set
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Default speaker on for calls

  // Callbacks
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserOffline;
  Function(String message)? onError;
  Function()? onJoinChannelSuccess;
  Function()? onLeaveChannel;

  // WebRTC configuration with multiple TURN servers for better connectivity
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      // Free TURN servers for NAT traversal
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
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
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

  /// Initialize the WebRTC service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('  VoiceCallService: Already initialized');
      return true;
    }

    try {
      debugPrint('  VoiceCallService: Requesting microphone permission...');
      final micPermission = await Permission.microphone.request();
      debugPrint(
        '  VoiceCallService: Microphone permission result: $micPermission',
      );

      if (!micPermission.isGranted) {
        debugPrint('  VoiceCallService: Microphone permission denied');
        // Don't call onError to avoid potential crash - just log
        return false;
      }

      _isInitialized = true;
      debugPrint('  VoiceCallService: Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('  VoiceCallService: Initialization error - $e');
      debugPrint('  VoiceCallService: Stack trace: $stackTrace');
      // Don't throw - return false to handle gracefully
      return false;
    }
  }

  /// Create peer connection with proper audio handling
  Future<void> _createPeerConnection() async {
    debugPrint('  VoiceCallService: Creating peer connection...');

    _peerConnection = await createPeerConnection(_configuration);
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        debugPrint(' VoiceCallService: ICE candidate generated');
        if (_currentCallId != null) {
          _sendIceCandidate(candidate);
        }
      }
    };

    // Handle ICE connection state
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint(' VoiceCallService: ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        debugPrint(
          ' VoiceCallService:  ICE Connected - Audio should work now!',
        );
        onUserJoined?.call(1);
      } else if (state ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint(' VoiceCallService:  ICE Disconnected/Failed');
        onUserOffline?.call(1);
      }
    };

    // Handle ICE gathering state
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint(' VoiceCallService: ICE gathering state: $state');
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint(' VoiceCallService: Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint(' VoiceCallService:  Peer connection established!');
      }
    };

    // CRITICAL: Handle remote audio track - this makes audio play
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint(
        '  VoiceCallService:  Remote track received: ${event.track.kind}, enabled: ${event.track.enabled}',
      );
      if (event.track.kind == 'audio') {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint(
            '  VoiceCallService:  Remote audio stream set! Stream ID: ${_remoteStream?.id}',
          );

          // Ensure audio track is enabled
          for (var track in _remoteStream!.getAudioTracks()) {
            track.enabled = true;
            debugPrint(
              '  VoiceCallService: Remote audio track enabled: ${track.id}',
            );
          }
        }
      }
    };

    // Also handle onAddStream for older WebRTC implementations
    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('  VoiceCallService:  Remote stream added via onAddStream');
      _remoteStream = stream;
      for (var track in stream.getAudioTracks()) {
        track.enabled = true;
        debugPrint(
          '  VoiceCallService: Remote audio track enabled: ${track.id}',
        );
      }
    };

    debugPrint('  VoiceCallService:  Peer connection created successfully');
  }

  /// Get local audio stream
  Future<void> _getLocalStream() async {
    debugPrint('  VoiceCallService: Getting local audio stream...');

    final mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint(
      ' VoiceCallService:  Local audio stream obtained, ID: ${_localStream?.id}',
    );

    // Add tracks to peer connection
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = true;
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint(' VoiceCallService: Added local audio track: ${track.id}');
    }

    // Enable speaker by default
    try {
      await Helper.setSpeakerphoneOn(true);
      _isSpeakerOn = true;
      debugPrint(' VoiceCallService: Speaker enabled');
    } catch (e) {
      debugPrint(' VoiceCallService: Could not set speaker: $e');
    }
  }

  /// Join a voice call - called by both caller and receiver
  Future<bool> joinCall(String callId, {bool isCaller = false}) async {
    debugPrint('  VoiceCallService: ========================================');
    debugPrint(
      '  VoiceCallService: Joining call $callId as ${isCaller ? "CALLER" : "RECEIVER"}',
    );
    debugPrint(
      '  VoiceCallService: Current state - isInCall: $_isInCall, currentCallId: $_currentCallId',
    );

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    // ALWAYS clean up previous state first
    debugPrint(' VoiceCallService: Cleaning up previous state...');
    await _cancelSubscriptions();

    // Close existing peer connection if any
    if (_peerConnection != null) {
      debugPrint(' VoiceCallService: Closing existing peer connection...');
      try {
        await _peerConnection!.close();
      } catch (e) {
        debugPrint(' VoiceCallService: Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    // Dispose existing streams
    if (_localStream != null) {
      try {
        for (var track in _localStream!.getAudioTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
      } catch (e) {
        debugPrint(' VoiceCallService: Error disposing local stream: $e');
      }
      _localStream = null;
    }

    if (_remoteStream != null) {
      try {
        await _remoteStream!.dispose();
      } catch (e) {
        debugPrint(' VoiceCallService: Error disposing remote stream: $e');
      }
      _remoteStream = null;
    }

    // Reset all flags
    _isInCall = false;
    _offerHandled = false;
    _answerHandled = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    debugPrint(' VoiceCallService: Previous state cleaned up');

    try {
      _currentCallId = callId;
      _isCaller = isCaller;
      _offerHandled = false;
      _answerHandled = false;
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      // Step 1: Create peer connection FIRST
      debugPrint(' VoiceCallService: Step 1 - Creating peer connection...');
      await _createPeerConnection();
      debugPrint(
        ' VoiceCallService: Step 1 DONE - Peer connection created, state: ${_peerConnection?.signalingState}',
      );

      // Step 2: Get local audio
      debugPrint(' VoiceCallService: Step 2 - Getting local audio...');
      await _getLocalStream();
      debugPrint(' VoiceCallService: Step 2 DONE - Local audio ready');

      _isInCall = true;

      if (isCaller) {
        // CALLER FLOW:
        // 1. Create offer and set local description
        // 2. Send offer to Firestore
        // 3. Start listening for answer
        debugPrint(
          ' VoiceCallService: CALLER Step 3 - Creating and sending offer...',
        );
        await _createOffer();
        debugPrint(' VoiceCallService: CALLER Step 3 DONE - Offer sent');

        debugPrint(
          ' VoiceCallService: CALLER Step 4 - Starting signaling listener...',
        );
        _listenForSignaling(callId);
        _listenForIceCandidates(callId);
      } else {
        // RECEIVER FLOW:
        // 1. Wait for and fetch offer from Firestore
        // 2. Set remote description with offer
        // 3. Create answer and set local description
        // 4. Send answer to Firestore
        // 5. Start listening for ICE candidates
        debugPrint(
          ' VoiceCallService: RECEIVER Step 3 - Waiting for offer from Firestore...',
        );

        // Try to fetch offer with retries (caller might not have created it yet)
        Map<String, dynamic>? offerData;
        for (int attempt = 0; attempt < 10; attempt++) {
          final callDoc = await _firestore
              .collection('calls')
              .doc(callId)
              .get();
          final callData = callDoc.data();

          if (callData != null && callData['offer'] != null) {
            offerData = Map<String, dynamic>.from(callData['offer']);
            debugPrint(
              ' VoiceCallService: RECEIVER - Found offer on attempt ${attempt + 1}',
            );
            break;
          }

          debugPrint(
            ' VoiceCallService: RECEIVER - No offer yet (attempt ${attempt + 1}/10), waiting 500ms...',
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (offerData != null) {
          debugPrint(
            ' VoiceCallService: RECEIVER Step 4 - Found offer, handling it NOW...',
          );
          _offerHandled = true;
          await _handleOffer(offerData);
          debugPrint(
            ' VoiceCallService: RECEIVER Step 4 DONE - Offer handled and answer sent',
          );

          debugPrint(
            ' VoiceCallService: RECEIVER Step 5 - Starting ICE candidate listener...',
          );
          _listenForIceCandidates(callId);
          // Also listen for any signaling updates
          _listenForSignaling(callId);
        } else {
          debugPrint(
            ' VoiceCallService: RECEIVER - No offer found after retries, starting listener...',
          );
          // Only start listening for offer if not found yet
          _listenForSignaling(callId);
          _listenForIceCandidates(callId);
        }
      }

      onJoinChannelSuccess?.call();
      debugPrint(' VoiceCallService:  Joined call successfully');
      return true;
    } catch (e) {
      debugPrint(' VoiceCallService:  Join call error - $e');
      onError?.call('Failed to join call: $e');
      return false;
    }
  }

  /// Cancel existing subscriptions
  Future<void> _cancelSubscriptions() async {
    debugPrint(' VoiceCallService: Cancelling existing subscriptions...');
    try {
      if (_signalingSubscription != null) {
        await _signalingSubscription!.cancel();
        _signalingSubscription = null;
        debugPrint(' VoiceCallService:  Cancelled signaling subscription');
      }
    } catch (e) {
      debugPrint(
        ' VoiceCallService: Error cancelling signaling subscription: $e',
      );
      _signalingSubscription = null;
    }
    try {
      if (_iceCandidateSubscription != null) {
        await _iceCandidateSubscription!.cancel();
        _iceCandidateSubscription = null;
        debugPrint(' VoiceCallService:  Cancelled ICE subscription');
      }
    } catch (e) {
      debugPrint(' VoiceCallService: Error cancelling ICE subscription: $e');
      _iceCandidateSubscription = null;
    }
  }

  /// Create and send offer (caller only)
  Future<void> _createOffer() async {
    try {
      debugPrint(' VoiceCallService: Creating offer...');

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      debugPrint(' VoiceCallService: Setting local description (offer)...');
      await _peerConnection!.setLocalDescription(offer);

      // Send offer via Firestore
      debugPrint(' VoiceCallService: Sending offer to Firestore...');
      await _firestore.collection('calls').doc(_currentCallId).update({
        'offer': {'sdp': offer.sdp, 'type': offer.type},
        'offerCreatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(' VoiceCallService:  Offer created and sent successfully');
    } catch (e) {
      debugPrint(' VoiceCallService:  Create offer error - $e');
    }
  }

  /// Handle received offer and create answer (receiver only)
  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    if (_peerConnection == null) {
      debugPrint(
        ' VoiceCallService:  Cannot handle offer - peer connection is null',
      );
      return;
    }

    try {
      debugPrint(' VoiceCallService: Handling offer...');

      final offer = RTCSessionDescription(
        offerData['sdp'] as String,
        offerData['type'] as String,
      );

      debugPrint(' VoiceCallService: Setting remote description (offer)...');
      await _peerConnection!.setRemoteDescription(offer);
      _remoteDescriptionSet = true;
      debugPrint(' VoiceCallService:  Remote description set');

      // Process any pending ICE candidates
      await _processPendingIceCandidates();

      // Create answer
      debugPrint(' VoiceCallService: Creating answer...');
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });

      debugPrint(' VoiceCallService: Setting local description (answer)...');
      await _peerConnection!.setLocalDescription(answer);

      // Send answer via Firestore
      debugPrint(' VoiceCallService: Sending answer to Firestore...');
      await _firestore.collection('calls').doc(_currentCallId).update({
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'answerCreatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(' VoiceCallService:  Answer created and sent successfully');
    } catch (e) {
      debugPrint(' VoiceCallService:  Handle offer error - $e');
    }
  }

  /// Handle received answer (caller only)
  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    if (_answerHandled) {
      debugPrint(' VoiceCallService: Answer already handled, skipping...');
      return;
    }

    if (_peerConnection == null) {
      debugPrint(
        ' VoiceCallService:  Cannot handle answer - peer connection is null',
      );
      return;
    }

    try {
      debugPrint(' VoiceCallService: Handling answer...');

      _answerHandled = true;

      final answer = RTCSessionDescription(
        answerData['sdp'] as String,
        answerData['type'] as String,
      );

      debugPrint(' VoiceCallService: Setting remote description (answer)...');
      await _peerConnection!.setRemoteDescription(answer);
      _remoteDescriptionSet = true;
      debugPrint(' VoiceCallService:  Remote description (answer) set');

      // Process any pending ICE candidates
      await _processPendingIceCandidates();
    } catch (e) {
      debugPrint(' VoiceCallService:  Handle answer error - $e');
      _answerHandled = false;
    }
  }

  /// Process pending ICE candidates after remote description is set
  Future<void> _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;

    debugPrint(
      ' VoiceCallService: Processing ${_pendingIceCandidates.length} pending ICE candidates...',
    );

    for (var candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
        debugPrint(' VoiceCallService: Added pending ICE candidate');
      } catch (e) {
        debugPrint(' VoiceCallService: Error adding pending candidate: $e');
      }
    }

    _pendingIceCandidates.clear();
    debugPrint(' VoiceCallService:  All pending ICE candidates processed');
  }

  /// Send ICE candidate via Firestore (separated by role)
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_currentCallId == null) return;

    try {
      final collection = _isCaller ? 'callerCandidates' : 'receiverCandidates';

      await _firestore
          .collection('calls')
          .doc(_currentCallId)
          .collection(collection)
          .add({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint(' VoiceCallService: ICE candidate sent to $collection');
    } catch (e) {
      debugPrint(' VoiceCallService: Send ICE candidate error - $e');
    }
  }

  /// Listen for signaling messages from Firestore (offer/answer only)
  void _listenForSignaling(String callId) {
    debugPrint(
      ' VoiceCallService: Starting signaling listener for call: $callId',
    );
    debugPrint(
      ' VoiceCallService: Current call ID: $_currentCallId, isCaller: $_isCaller',
    );

    // Listen for offer/answer updates
    _signalingSubscription = _firestore.collection('calls').doc(callId).snapshots().listen((
      snapshot,
    ) async {
      final data = snapshot.data();
      if (data == null) return;

      // Skip if this is not our current call
      if (_currentCallId != callId) {
        debugPrint(
          ' VoiceCallService: Call ID mismatch, ignoring (expected: $_currentCallId, got: $callId)',
        );
        return;
      }

      // Skip if peer connection is not ready
      if (_peerConnection == null) {
        debugPrint(
          ' VoiceCallService: Peer connection not ready, ignoring signaling event for call: $callId',
        );
        return;
      }

      // Caller waits for answer
      if (_isCaller && data['answer'] != null && !_answerHandled) {
        debugPrint(
          ' VoiceCallService: CALLER - Received answer from Firestore for call: $callId',
        );
        final signalingState = _peerConnection?.signalingState;
        debugPrint(
          ' VoiceCallService: Current signaling state: $signalingState',
        );

        if (signalingState ==
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          await _handleAnswer(Map<String, dynamic>.from(data['answer']));
        }
      }

      // Receiver waits for offer (if not already handled)
      if (!_isCaller && data['offer'] != null && !_offerHandled) {
        debugPrint(
          ' VoiceCallService: RECEIVER - Received offer from Firestore for call: $callId',
        );
        final signalingState = _peerConnection?.signalingState;
        debugPrint(
          ' VoiceCallService: Current signaling state: $signalingState',
        );

        if (signalingState == RTCSignalingState.RTCSignalingStateStable) {
          _offerHandled = true;
          await _handleOffer(Map<String, dynamic>.from(data['offer']));
        }
      }
    });
  }

  /// Listen for ICE candidates from the other party
  void _listenForIceCandidates(String callId) {
    final otherCandidatesCollection = _isCaller
        ? 'receiverCandidates'
        : 'callerCandidates';
    debugPrint(
      ' VoiceCallService: Starting ICE candidate listener on: $otherCandidatesCollection',
    );

    _iceCandidateSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection(otherCandidatesCollection)
        .snapshots()
        .listen((snapshot) async {
          // Skip if peer connection is not ready
          if (_peerConnection == null) {
            debugPrint(
              ' VoiceCallService: ICE - Peer connection null, skipping',
            );
            return;
          }

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null && data['candidate'] != null) {
                final candidate = RTCIceCandidate(
                  data['candidate'] as String?,
                  data['sdpMid'] as String?,
                  data['sdpMLineIndex'] as int?,
                );

                // Only add ICE candidate if remote description is set
                if (_remoteDescriptionSet && _peerConnection != null) {
                  try {
                    await _peerConnection!.addCandidate(candidate);
                    debugPrint(
                      ' VoiceCallService:  Added ICE candidate from $otherCandidatesCollection',
                    );
                  } catch (e) {
                    debugPrint(' VoiceCallService: Error adding candidate: $e');
                  }
                } else {
                  // Queue the candidate for later
                  _pendingIceCandidates.add(candidate);
                  debugPrint(
                    ' VoiceCallService: Queued ICE candidate (remote desc not set yet, count: ${_pendingIceCandidates.length})',
                  );
                }
              }
            }
          }
        });
  }

  /// Leave the current call
  Future<void> leaveCall() async {
    debugPrint('  VoiceCallService: Leaving call...');

    // Cancel subscriptions first
    try {
      await _cancelSubscriptions();
    } catch (e) {
      debugPrint('  VoiceCallService: Error cancelling subscriptions: $e');
    }

    // Stop local audio tracks
    try {
      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          try {
            track.stop();
          } catch (e) {
            debugPrint('  VoiceCallService: Error stopping track: $e');
          }
        }
        try {
          await _localStream!.dispose();
        } catch (e) {
          debugPrint('  VoiceCallService: Error disposing local stream: $e');
        }
        _localStream = null;
      }
    } catch (e) {
      debugPrint('  VoiceCallService: Error handling local stream: $e');
      _localStream = null;
    }

    // Dispose remote stream
    try {
      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }
    } catch (e) {
      debugPrint('  VoiceCallService: Error disposing remote stream: $e');
      _remoteStream = null;
    }

    // Close peer connection
    try {
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
    } catch (e) {
      debugPrint('  VoiceCallService: Error closing peer connection: $e');
      _peerConnection = null;
    }

    // Reset all state
    _currentCallId = null;
    _isInCall = false;
    _isMuted = false;
    _isCaller = false;
    _offerHandled = false;
    _answerHandled = false;
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    try {
      onLeaveChannel?.call();
    } catch (e) {
      debugPrint('  VoiceCallService: Error calling onLeaveChannel: $e');
    }
    debugPrint('  VoiceCallService: ✅ Left call successfully');
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
    debugPrint(' VoiceCallService: Mute: $_isMuted');
  }

  /// Set mute state
  Future<void> setMute(bool muted) async {
    if (_localStream == null) return;

    _isMuted = muted;
    for (var track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
    debugPrint(' VoiceCallService: Mute set to $muted');
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      debugPrint(' VoiceCallService: Speaker: $_isSpeakerOn');
    } catch (e) {
      debugPrint(' VoiceCallService: Toggle speaker error - $e');
    }
  }

  /// Set speaker state
  Future<void> setSpeaker(bool enabled) async {
    _isSpeakerOn = enabled;
    try {
      await Helper.setSpeakerphoneOn(enabled);
      debugPrint(' VoiceCallService: Speaker set to $enabled');
    } catch (e) {
      debugPrint(' VoiceCallService: Set speaker error - $e');
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    debugPrint(' VoiceCallService: Disposing');
    await leaveCall();
    _isInitialized = false;
  }
}
