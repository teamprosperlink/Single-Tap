import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

/// Video Call Service using WebRTC via Firebase Signaling
/// Works on all Android and iOS devices with camera support
class VideoCallService {
  static final VideoCallService _instance = VideoCallService._internal();
  factory VideoCallService() => _instance;
  VideoCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;
  bool _isCaller = false;
  bool _answerHandled = false;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _iceCandidateSubscription;

  // Queue for ICE candidates received before remote description is set
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _remoteStreamAssigned =
      false; // Track if remote stream has been assigned to renderer

  // Video-specific state
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  bool _isInitialized = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true; // Default speaker on for calls
  bool _isRequestingPermissions =
      false; // Guard flag to prevent simultaneous permission requests

  // Callbacks
  Function(int uid)? onUserJoined;
  Function(int uid)? onUserOffline;
  Function(String message)? onError;
  Function()? onJoinChannelSuccess;
  Function()? onLeaveChannel;
  Function()?
  onRemoteStreamReady; // New callback for when remote stream is ready
  Function()? onLocalStreamReady; // New callback for when local stream is ready

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
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  /// Initialize the WebRTC service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('  VideoCallService: Already initialized');
      return true;
    }

    //   FIX: Prevent simultaneous permission requests (causes PlatformException race condition)
    if (_isRequestingPermissions) {
      debugPrint(
        '  VideoCallService: Permission request already in progress, waiting...',
      );
      // Wait for ongoing permission request to complete
      while (_isRequestingPermissions) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Check if initialization succeeded during wait
      if (_isInitialized) {
        debugPrint('  VideoCallService: Already initialized after waiting');
        return true;
      }
    }

    try {
      _isRequestingPermissions = true;
      debugPrint('  VideoCallService: Requesting permissions...');

      // Check current permission status first (avoid unnecessary requests)
      final micStatus = await Permission.microphone.status;
      final cameraStatus = await Permission.camera.status;

      debugPrint(
        '  VideoCallService: Current permissions - Mic: $micStatus, Camera: $cameraStatus',
      );

      PermissionStatus micPermission = micStatus;
      PermissionStatus cameraPermission = cameraStatus;

      // Only request if not already granted
      if (!micStatus.isGranted) {
        micPermission = await Permission.microphone.request();
        debugPrint(
          '  VideoCallService: Microphone permission result: $micPermission',
        );
      }

      if (!cameraStatus.isGranted) {
        cameraPermission = await Permission.camera.request();
        debugPrint(
          '  VideoCallService: Camera permission result: $cameraPermission',
        );
      }

      _isRequestingPermissions = false;

      if (!micPermission.isGranted || !cameraPermission.isGranted) {
        debugPrint('  VideoCallService: Required permissions denied');
        onError?.call(
          'Camera and microphone permissions are required for video calls',
        );
        return false;
      }

      // Initialize video renderers - CRITICAL for video display
      debugPrint('  VideoCallService: Initializing video renderers...');

      // Initialize renderers ONLY if not already initialized
      // DO NOT dispose and reinitialize - causes "used after disposed" errors
      try {
        if (_localRenderer.textureId == null) {
          await _localRenderer.initialize();
          debugPrint('  VideoCallService:   Local renderer initialized');
        } else {
          debugPrint(
            '  VideoCallService:   Local renderer already initialized (textureId: ${_localRenderer.textureId})',
          );
        }
      } catch (e) {
        debugPrint('  VideoCallService: Error initializing local renderer: $e');
        // Try to initialize anyway
        await _localRenderer.initialize();
        debugPrint('  VideoCallService:   Local renderer initialized on retry');
      }

      try {
        if (_remoteRenderer.textureId == null) {
          await _remoteRenderer.initialize();
          debugPrint('  VideoCallService:   Remote renderer initialized');
        } else {
          debugPrint(
            '  VideoCallService:   Remote renderer already initialized (textureId: ${_remoteRenderer.textureId})',
          );
        }
      } catch (e) {
        debugPrint(
          '  VideoCallService: Error initializing remote renderer: $e',
        );
        // Try to initialize anyway
        await _remoteRenderer.initialize();
        debugPrint(
          '  VideoCallService:   Remote renderer initialized on retry',
        );
      }

      _isInitialized = true;
      debugPrint('  VideoCallService:   Initialized successfully');
      return true;
    } catch (e, stackTrace) {
      _isRequestingPermissions = false; //   Reset flag on error
      debugPrint('  VideoCallService:   Initialization error - $e');
      debugPrint('  VideoCallService: Stack trace: $stackTrace');
      onError?.call('Failed to initialize video call: $e');
      return false;
    }
  }

  /// Create peer connection with proper video and audio handling
  Future<void> _createPeerConnection() async {
    debugPrint('  VideoCallService: Creating peer connection...');

    //   FIX: Catch UnimplementedError from createPeerConnection on unsupported platforms
    try {
      _peerConnection = await createPeerConnection(_configuration);
    } on UnimplementedError catch (e) {
      debugPrint(
        '  VideoCallService:   createPeerConnection not implemented on this platform: $e',
      );
      throw Exception('Video calling is not supported on this device');
    }

    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        debugPrint(' VideoCallService: ICE candidate generated');
        if (_currentCallId != null) {
          _sendIceCandidate(candidate);
        }
      }
    };

    // Handle ICE connection state
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint(' VideoCallService: ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        debugPrint(
          ' VideoCallService:  ICE Connected - Video/Audio should work now!',
        );
        onUserJoined?.call(1);
      } else if (state ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint(' VideoCallService:  ICE Disconnected/Failed');
        onUserOffline?.call(1);
      }
    };

    // Handle ICE gathering state
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint(' VideoCallService: ICE gathering state: $state');
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint(' VideoCallService: Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint(' VideoCallService:  Peer connection established!');
      }
    };

    // CRITICAL: Handle remote tracks (both video and audio)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint(
        '  VideoCallService:  Remote track received: ${event.track.kind}, enabled: ${event.track.enabled}',
      );

      if (event.streams.isNotEmpty) {
        final newStream = event.streams[0];

        // Only assign stream if it's different or first time
        if (_remoteStream == null || _remoteStream!.id != newStream.id) {
          _remoteStream = newStream;
          debugPrint(
            '  VideoCallService:  Remote stream set! Stream ID: ${_remoteStream?.id}',
          );
        }

        debugPrint(
          '  VideoCallService: Remote stream has ${_remoteStream!.getAudioTracks().length} audio tracks and ${_remoteStream!.getVideoTracks().length} video tracks',
        );

        // Enable the incoming track
        event.track.enabled = true;
        debugPrint(
          '  VideoCallService: Track enabled: ${event.track.id}, kind: ${event.track.kind}, enabled: ${event.track.enabled}',
        );

        // Only assign to renderer once we have both audio and video tracks
        // OR if we already assigned but got a new track
        final hasAudio = _remoteStream!.getAudioTracks().isNotEmpty;
        final hasVideo = _remoteStream!.getVideoTracks().isNotEmpty;

        debugPrint(
          '  VideoCallService: Stream status - hasAudio: $hasAudio, hasVideo: $hasVideo, alreadyAssigned: $_remoteStreamAssigned',
        );

        // CRITICAL: Always reassign stream when video track arrives
        // This ensures EglRenderer properly initializes with the video track
        if (hasVideo && event.track.kind == 'video') {
          debugPrint(
            '  VideoCallService:   VIDEO TRACK ARRIVED - Assigning to renderer...',
          );

          //   FIX: Force video track to be enabled BEFORE assigning to renderer
          for (var track in _remoteStream!.getVideoTracks()) {
            track.enabled = true;
            debugPrint(
              '  VideoCallService: Force enabled video track: ${track.id}',
            );
          }

          // Assign remote stream to renderer
          _remoteRenderer.srcObject = _remoteStream;
          _remoteStreamAssigned = true;

          debugPrint(
            '  VideoCallService:   Remote renderer srcObject set: ${_remoteRenderer.srcObject != null}',
          );
          debugPrint(
            '  VideoCallService:   Remote renderer textureId: ${_remoteRenderer.textureId}',
          );

          //   FIX: Add small delay to ensure renderer fully processes the stream
          Future.delayed(const Duration(milliseconds: 300), () {
            // Double-check video tracks are still enabled
            if (_remoteStream != null) {
              for (var track in _remoteStream!.getVideoTracks()) {
                if (!track.enabled) {
                  track.enabled = true;
                  debugPrint(
                    '  VideoCallService: Re-enabled video track after delay: ${track.id}',
                  );
                }
              }
            }
            onRemoteStreamReady?.call();
            debugPrint(
              '  VideoCallService:   Remote stream renderer updated, callback triggered',
            );
          });
        } else if ((hasAudio && hasVideo) && !_remoteStreamAssigned) {
          // Fallback: assign if we have both tracks but haven't assigned yet
          debugPrint(
            '  VideoCallService: Assigning complete stream to renderer (fallback)...',
          );

          //   FIX: Enable all tracks before assignment
          for (var track in _remoteStream!.getVideoTracks()) {
            track.enabled = true;
          }
          for (var track in _remoteStream!.getAudioTracks()) {
            track.enabled = true;
          }

          _remoteRenderer.srcObject = _remoteStream;
          _remoteStreamAssigned = true;

          debugPrint(
            '  VideoCallService:   Remote renderer srcObject set: ${_remoteRenderer.srcObject != null}',
          );
          debugPrint(
            '  VideoCallService:   Remote renderer textureId: ${_remoteRenderer.textureId}',
          );

          // Notify that remote stream is ready (for UI update)
          onRemoteStreamReady?.call();
          debugPrint(
            '  VideoCallService:   Remote stream renderer updated, callback triggered',
          );
        }
      }
    };

    // Also handle onAddStream for older WebRTC implementations
    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('  VideoCallService:  Remote stream added via onAddStream');
      debugPrint(
        '  VideoCallService: Stream has ${stream.getAudioTracks().length} audio tracks and ${stream.getVideoTracks().length} video tracks',
      );

      // Don't re-assign if we already have a stream from onTrack
      if (_remoteStreamAssigned) {
        debugPrint(
          '  VideoCallService: Remote stream already assigned via onTrack, skipping onAddStream',
        );
        return;
      }

      _remoteStream = stream;

      for (var track in stream.getAudioTracks()) {
        track.enabled = true;
        debugPrint(
          '  VideoCallService: Audio track enabled: ${track.id}, kind: ${track.kind}',
        );
      }

      for (var track in stream.getVideoTracks()) {
        track.enabled = true;
        debugPrint(
          '  VideoCallService: Video track enabled: ${track.id}, kind: ${track.kind}, enabled: ${track.enabled}',
        );
      }

      debugPrint(
        '  VideoCallService: Assigning remote stream to renderer (onAddStream)...',
      );
      _remoteRenderer.srcObject = _remoteStream;
      _remoteStreamAssigned = true;

      debugPrint(
        '  VideoCallService:   Remote renderer srcObject set (onAddStream): ${_remoteRenderer.srcObject != null}',
      );

      // Notify that remote stream is ready (for UI update)
      onRemoteStreamReady?.call();
      debugPrint(
        '  VideoCallService:   Remote stream renderer updated (onAddStream), callback triggered',
      );
    };

    debugPrint('  VideoCallService:  Peer connection created successfully');
  }

  /// Get local video and audio stream
  Future<void> _getLocalStream() async {
    debugPrint('  VideoCallService: Getting local video stream...');

    // Platform-optimized media constraints
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
      debugPrint(
        '  VideoCallService: Requesting user media with constraints...',
      );

      //   FIX: Catch UnimplementedError from getUserMedia on unsupported platforms
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(
          mediaConstraints,
        );
      } on UnimplementedError catch (e) {
        debugPrint(
          '  VideoCallService:   getUserMedia not implemented on this platform: $e',
        );
        throw Exception('Video calling is not supported on this device');
      }

      if (_localStream == null) {
        throw Exception('Failed to get media stream - null returned');
      }

      debugPrint(
        '  VideoCallService:   Local stream obtained, ID: ${_localStream!.id}',
      );
      debugPrint(
        '  VideoCallService: Local stream has ${_localStream!.getAudioTracks().length} audio tracks and ${_localStream!.getVideoTracks().length} video tracks',
      );

      // Verify we have video tracks
      if (_localStream!.getVideoTracks().isEmpty) {
        throw Exception('No video tracks in local stream');
      }

      if (_localStream!.getAudioTracks().isEmpty) {
        throw Exception('No audio tracks in local stream');
      }

      // CRITICAL: Enable all tracks explicitly
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = true;
        debugPrint(
          '  VideoCallService:   Video track enabled: ${track.id}, kind: ${track.kind}, enabled: ${track.enabled}',
        );
      }

      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
        debugPrint(
          '  VideoCallService:   Audio track enabled: ${track.id}, kind: ${track.kind}, enabled: ${track.enabled}',
        );
      }

      // Add tracks to peer connection
      debugPrint('  VideoCallService: Adding tracks to peer connection...');
      for (var track in _localStream!.getAudioTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
        debugPrint(
          '  VideoCallService:   Added audio track to peer connection',
        );
      }

      for (var track in _localStream!.getVideoTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
        debugPrint(
          '  VideoCallService:   Added video track to peer connection',
        );
      }

      // Assign local stream to renderer
      debugPrint('  VideoCallService: Assigning local stream to renderer...');
      debugPrint(
        '  VideoCallService: Local renderer textureId BEFORE assignment: ${_localRenderer.textureId}',
      );
      debugPrint('  VideoCallService: Local stream ID: ${_localStream!.id}');
      // Note: .active property not available on all platforms (UnimplementedError on some Android devices)

      _localRenderer.srcObject = _localStream;

      // Wait for renderer to process the stream
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify renderer has the stream
      if (_localRenderer.srcObject == null) {
        throw Exception('Failed to assign local stream to renderer');
      }

      debugPrint(
        '  VideoCallService:   Local renderer srcObject set successfully',
      );
      debugPrint(
        '  VideoCallService: Local renderer textureId AFTER assignment: ${_localRenderer.textureId}',
      );
      debugPrint(
        '  VideoCallService: Local renderer srcObject ID: ${_localRenderer.srcObject?.id}',
      );

      // Notify that local stream is ready (for UI update)
      onLocalStreamReady?.call();
      debugPrint(
        '  VideoCallService: 📹 Local stream ready callback triggered',
      );

      // Enable speaker by default for video calls
      try {
        //   FIX: Wrap in try-catch to handle UnimplementedError on some platforms
        await Helper.setSpeakerphoneOn(true);
        _isSpeakerOn = true;
        debugPrint('  VideoCallService:   Speaker enabled');
      } on UnimplementedError catch (e) {
        debugPrint(
          '  VideoCallService: ⚠️ Speaker control not supported on this platform: $e',
        );
        _isSpeakerOn = true; // Assume speaker is on by default
      } catch (e) {
        debugPrint('  VideoCallService: ⚠️ Could not set speaker: $e');
        _isSpeakerOn = true; // Assume speaker is on by default
      }
    } catch (e, stackTrace) {
      debugPrint('  VideoCallService:   Error getting local stream: $e');
      debugPrint('  VideoCallService: Stack trace: $stackTrace');
      onError?.call('Failed to access camera: $e');
      rethrow;
    }
  }

  /// Join a video call - called by both caller and receiver
  Future<bool> joinCall(String callId, {bool isCaller = false}) async {
    debugPrint('  VideoCallService: ========================================');
    debugPrint(
      '  VideoCallService: Joining call $callId as ${isCaller ? "CALLER" : "RECEIVER"}',
    );
    debugPrint(
      '  VideoCallService: Current state - isInCall: $_isInCall, currentCallId: $_currentCallId',
    );

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    // ALWAYS clean up previous state first
    debugPrint(' VideoCallService: Cleaning up previous state...');
    await _cancelSubscriptions();

    // Close existing peer connection if any
    if (_peerConnection != null) {
      debugPrint(' VideoCallService: Closing existing peer connection...');
      try {
        await _peerConnection!.close();
      } catch (e) {
        debugPrint(' VideoCallService: Error closing peer connection: $e');
      }
      _peerConnection = null;
    }

    // Dispose existing streams
    if (_localStream != null) {
      try {
        for (var track in _localStream!.getAudioTracks()) {
          track.stop();
        }
        for (var track in _localStream!.getVideoTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
      } catch (e) {
        debugPrint(' VideoCallService: Error disposing local stream: $e');
      }
      _localStream = null;
    }

    if (_remoteStream != null) {
      try {
        await _remoteStream!.dispose();
      } catch (e) {
        debugPrint(' VideoCallService: Error disposing remote stream: $e');
      }
      _remoteStream = null;
    }

    // Reset renderers
    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      debugPrint(' VideoCallService: Error resetting renderers: $e');
    }

    // Reset all flags
    _isInCall = false;
    _answerHandled = false;
    _remoteDescriptionSet = false;
    _remoteStreamAssigned = false;
    _pendingIceCandidates.clear();

    debugPrint(' VideoCallService: Previous state cleaned up');

    try {
      _currentCallId = callId;
      _isCaller = isCaller;
      _answerHandled = false;
      _remoteDescriptionSet = false;
      _remoteStreamAssigned = false;
      _pendingIceCandidates.clear();

      // Step 1: Create peer connection FIRST
      debugPrint(' VideoCallService: Step 1 - Creating peer connection...');
      await _createPeerConnection();
      debugPrint(
        ' VideoCallService: Step 1 DONE - Peer connection created, state: ${_peerConnection?.signalingState}',
      );

      // Step 2: Get local video and audio
      debugPrint(' VideoCallService: Step 2 - Getting local video stream...');
      await _getLocalStream();
      debugPrint(' VideoCallService: Step 2 DONE - Local video/audio ready');

      _isInCall = true;

      if (isCaller) {
        // CALLER FLOW:
        debugPrint(
          ' VideoCallService: CALLER Step 3 - Creating and sending offer...',
        );
        await _createOffer();
        debugPrint(' VideoCallService: CALLER Step 3 DONE - Offer sent');

        debugPrint(
          ' VideoCallService: CALLER Step 4 - Starting signaling listener...',
        );
        _listenForSignaling(callId);
        _listenForIceCandidates(callId);
      } else {
        // RECEIVER FLOW:
        debugPrint(
          ' VideoCallService: RECEIVER Step 3 - Waiting for offer from Firestore...',
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
              ' VideoCallService: RECEIVER - Found offer on attempt ${attempt + 1}',
            );
            break;
          }

          debugPrint(
            ' VideoCallService: RECEIVER - No offer yet (attempt ${attempt + 1}/10), waiting 500ms...',
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (offerData != null) {
          debugPrint(
            ' VideoCallService: RECEIVER Step 4 - Found offer, handling it NOW...',
          );
          await _handleOffer(offerData);
          debugPrint(
            ' VideoCallService: RECEIVER Step 4 DONE - Offer handled and answer sent',
          );

          debugPrint(
            ' VideoCallService: RECEIVER Step 5 - Starting ICE candidate listener...',
          );
          _listenForIceCandidates(callId);
          _listenForSignaling(callId);
        } else {
          debugPrint(
            ' VideoCallService: RECEIVER - No offer found after retries, starting listener...',
          );
          _listenForSignaling(callId);
          _listenForIceCandidates(callId);
        }
      }

      onJoinChannelSuccess?.call();
      debugPrint(' VideoCallService:  Joined call successfully');
      return true;
    } on UnimplementedError catch (e, stackTrace) {
      debugPrint(' VideoCallService:  UnimplementedError in joinCall - $e');
      debugPrint(' VideoCallService: Stack trace: $stackTrace');
      onError?.call(
        'Video calling is not supported on this device. Error: ${e.toString()}',
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint(' VideoCallService:  Join call error - $e');
      debugPrint(' VideoCallService: Stack trace: $stackTrace');
      onError?.call('Failed to join call: $e');
      return false;
    }
  }

  /// Cancel existing subscriptions
  Future<void> _cancelSubscriptions() async {
    debugPrint(' VideoCallService: Cancelling existing subscriptions...');
    try {
      await _signalingSubscription?.cancel();
      await _iceCandidateSubscription?.cancel();
      _signalingSubscription = null;
      _iceCandidateSubscription = null;
      debugPrint(' VideoCallService: Subscriptions cancelled');
    } catch (e) {
      debugPrint(' VideoCallService: Error cancelling subscriptions: $e');
    }
  }

  /// Create offer (caller side)
  Future<void> _createOffer() async {
    debugPrint(' VideoCallService: Creating offer...');

    try {
      final offer = await _peerConnection!.createOffer();
      debugPrint(
        ' VideoCallService: Offer created: ${offer.sdp?.substring(0, 50)}...',
      );

      await _peerConnection!.setLocalDescription(offer);
      debugPrint(' VideoCallService: Local description set');

      final offerData = {'type': offer.type, 'sdp': offer.sdp};

      await _firestore.collection('calls').doc(_currentCallId).update({
        'offer': offerData,
      });
      debugPrint(' VideoCallService: Offer sent to Firestore');
    } catch (e) {
      debugPrint(' VideoCallService: Error creating offer: $e');
      rethrow;
    }
  }

  /// Handle offer (receiver side)
  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    debugPrint(' VideoCallService: Handling offer...');

    try {
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);

      await _peerConnection!.setRemoteDescription(offer);
      _remoteDescriptionSet = true;
      debugPrint(' VideoCallService: Remote description set');

      // Add any pending ICE candidates now that remote description is set
      if (_pendingIceCandidates.isNotEmpty) {
        debugPrint(
          ' VideoCallService: Adding ${_pendingIceCandidates.length} pending ICE candidates...',
        );
        for (var candidate in _pendingIceCandidates) {
          try {
            await _peerConnection!.addCandidate(candidate);
          } catch (e) {
            debugPrint(' VideoCallService: Error adding pending candidate: $e');
          }
        }
        _pendingIceCandidates.clear();
      }

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      debugPrint(
        ' VideoCallService: Answer created: ${answer.sdp?.substring(0, 50)}...',
      );

      await _peerConnection!.setLocalDescription(answer);
      debugPrint(' VideoCallService: Local description set (answer)');

      final answerData = {'type': answer.type, 'sdp': answer.sdp};

      await _firestore.collection('calls').doc(_currentCallId).update({
        'answer': answerData,
      });
      debugPrint(' VideoCallService: Answer sent to Firestore');
    } catch (e) {
      debugPrint(' VideoCallService: Error handling offer: $e');
      rethrow;
    }
  }

  /// Listen for signaling updates (offer/answer)
  void _listenForSignaling(String callId) {
    debugPrint(' VideoCallService: Listening for signaling on $callId...');

    _signalingSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!snapshot.exists) return;

            final callData = snapshot.data() as Map<String, dynamic>;

            // CALLER: Listen for answer
            if (_isCaller && !_answerHandled && callData['answer'] != null) {
              _answerHandled = true;
              debugPrint(
                ' VideoCallService: CALLER - Answer received from receiver',
              );
              try {
                final answer = RTCSessionDescription(
                  callData['answer']['sdp'],
                  callData['answer']['type'],
                );
                await _peerConnection!.setRemoteDescription(answer);
                _remoteDescriptionSet = true;
                debugPrint(
                  ' VideoCallService: CALLER - Remote description set (answer)',
                );

                // Add any pending ICE candidates
                if (_pendingIceCandidates.isNotEmpty) {
                  debugPrint(
                    ' VideoCallService: CALLER - Adding ${_pendingIceCandidates.length} pending ICE candidates...',
                  );
                  for (var candidate in _pendingIceCandidates) {
                    try {
                      await _peerConnection!.addCandidate(candidate);
                    } catch (e) {
                      debugPrint(
                        ' VideoCallService: Error adding pending candidate: $e',
                      );
                    }
                  }
                  _pendingIceCandidates.clear();
                }
              } catch (e) {
                debugPrint(' VideoCallService: Error handling answer: $e');
              }
            }
          },
          onError: (error) {
            debugPrint(
              ' VideoCallService: Error listening for signaling: $error',
            );
          },
        );
  }

  /// Listen for ICE candidates
  void _listenForIceCandidates(String callId) {
    debugPrint(' VideoCallService: Listening for ICE candidates...');

    final path = _isCaller ? 'callerCandidates' : 'receiverCandidates';

    _iceCandidateSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .collection(path)
        .snapshots()
        .listen(
          (snapshot) async {
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                if (data.isEmpty) continue;

                // Safely extract and convert values
                final candidateStr = data['candidate'];
                final sdpMidStr = data['sdpMid'];
                final sdpMLineIndexValue = data['sdpMLineIndex'];

                if (candidateStr == null) {
                  debugPrint(
                    ' VideoCallService: Skipping candidate - no candidate string',
                  );
                  continue;
                }

                // Safely convert sdpMLineIndex to int
                int? mLineIndexInt;
                if (sdpMLineIndexValue is int) {
                  mLineIndexInt = sdpMLineIndexValue;
                } else if (sdpMLineIndexValue is String) {
                  mLineIndexInt = int.tryParse(sdpMLineIndexValue);
                } else if (sdpMLineIndexValue != null) {
                  debugPrint(
                    ' VideoCallService: Warning - sdpMLineIndex is unexpected type: ${sdpMLineIndexValue.runtimeType}',
                  );
                  mLineIndexInt = int.tryParse(sdpMLineIndexValue.toString());
                }

                // Create candidate safely without forceful casts
                final candidate = RTCIceCandidate(
                  candidateStr,
                  sdpMidStr,
                  mLineIndexInt,
                );

                if (_remoteDescriptionSet) {
                  await _peerConnection!.addCandidate(candidate);
                  debugPrint(' VideoCallService: ICE candidate added');
                } else {
                  _pendingIceCandidates.add(candidate);
                  debugPrint(
                    ' VideoCallService: ICE candidate queued (${_pendingIceCandidates.length} pending)',
                  );
                }
              } catch (e, st) {
                debugPrint(
                  ' VideoCallService: Error processing ICE candidate: $e',
                );
                debugPrint(' VideoCallService: Stack trace: $st');
              }
            }
          },
          onError: (error) {
            debugPrint(
              ' VideoCallService: Error listening for ICE candidates: $error',
            );
          },
        );
  }

  /// Send ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (_currentCallId == null) return;

    try {
      final path = _isCaller ? 'callerCandidates' : 'receiverCandidates';

      // Convert sdpMLineIndex to string to avoid type issues
      final sdpMLineIndexStr = candidate.sdpMLineIndex?.toString();

      await _firestore
          .collection('calls')
          .doc(_currentCallId!)
          .collection(path)
          .add({
            'candidate': candidate.candidate,
            'sdpMLineIndex': sdpMLineIndexStr,
            'sdpMid': candidate.sdpMid,
          });
    } catch (e) {
      debugPrint(' VideoCallService: Error sending ICE candidate: $e');
    }
  }

  /// Switch camera (front <-> back)
  Future<void> switchCamera() async {
    try {
      debugPrint(' VideoCallService: Switching camera...');
      _isFrontCamera = !_isFrontCamera;

      if (_localStream == null || _peerConnection == null) {
        debugPrint(
          ' VideoCallService: Stream or peer connection not available',
        );
        return;
      }

      // Get senders before stopping tracks
      final senders = await _peerConnection!.getSenders();
      final videoSender = senders.firstWhere(
        (sender) => sender.track?.kind == 'video',
        orElse: () => throw Exception('No video sender found'),
      );

      // Stop current video tracks
      final oldVideoTracks = _localStream!.getVideoTracks();
      for (var track in oldVideoTracks) {
        await track.stop();
      }

      // Get new stream with opposite camera
      final mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '15',
          },
          'optional': [
            {'minWidth': '1280'},
            {'minHeight': '720'},
            {'minFrameRate': '30'},
          ],
        },
      };

      final newStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      final newVideoTrack = newStream.getVideoTracks().first;

      // Ensure new track is enabled
      newVideoTrack.enabled = _isVideoEnabled;
      debugPrint(
        ' VideoCallService: New video track enabled: ${newVideoTrack.enabled}',
      );

      // Replace the video track in the peer connection
      await videoSender.replaceTrack(newVideoTrack);
      debugPrint(' VideoCallService: Video track replaced in peer connection');

      // Update local stream with new video track (keep existing audio)
      final audioTracks = _localStream!.getAudioTracks();
      _localStream = newStream;

      // Re-add audio tracks to the new stream
      for (var audioTrack in audioTracks) {
        _localStream!.addTrack(audioTrack);
      }

      // Update local renderer with new stream
      _localRenderer.srcObject = _localStream;

      // Force a small delay to ensure renderer is updated
      await Future.delayed(const Duration(milliseconds: 100));

      // Notify that local stream is ready (for UI update after camera switch)
      onLocalStreamReady?.call();

      debugPrint(
        ' VideoCallService:   Camera switched to ${_isFrontCamera ? "front" : "back"}, renderer updated',
      );
    } catch (e) {
      debugPrint(' VideoCallService: Error switching camera: $e');
      // Revert camera flag on error
      _isFrontCamera = !_isFrontCamera;
      onError?.call('Failed to switch camera: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      _isVideoEnabled = !_isVideoEnabled;
      debugPrint(' VideoCallService: Video toggled: $_isVideoEnabled');

      if (_localStream != null) {
        for (var track in _localStream!.getVideoTracks()) {
          track.enabled = _isVideoEnabled;
        }
      }
    } catch (e) {
      debugPrint(' VideoCallService: Error toggling video: $e');
      onError?.call('Failed to toggle video: $e');
    }
  }

  /// Mute/unmute audio
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      debugPrint(' VideoCallService: Mute toggled: $_isMuted');

      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = !_isMuted;
        }
      }
    } catch (e) {
      debugPrint(' VideoCallService: Error toggling mute: $e');
      onError?.call('Failed to toggle mute: $e');
    }
  }

  /// Toggle speaker on/off
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;

      //   FIX: Wrap in try-catch to handle UnimplementedError on some platforms
      try {
        await Helper.setSpeakerphoneOn(_isSpeakerOn);
        debugPrint(' VideoCallService: Speaker toggled: $_isSpeakerOn');
      } on UnimplementedError catch (e) {
        debugPrint(
          ' VideoCallService: Speaker control not supported on this platform: $e',
        );
        // Just update the state without calling native method
      }
    } catch (e) {
      debugPrint(' VideoCallService: Error toggling speaker: $e');
      // Revert state on error
      _isSpeakerOn = !_isSpeakerOn;
      onError?.call('Failed to toggle speaker: $e');
    }
  }

  /// Hang up the call
  Future<void> hangup() async {
    debugPrint('  VideoCallService: Hanging up...');

    try {
      await _cancelSubscriptions();

      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

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

      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;

      _isInCall = false;
      _isMuted = false;
      _isSpeakerOn = true;
      _isVideoEnabled = true;
      _isFrontCamera = true;
      _currentCallId = null;
      _remoteStreamAssigned = false;
      _remoteDescriptionSet = false;
      _answerHandled = false;

      onLeaveChannel?.call();
      debugPrint('  VideoCallService: Hung up successfully');
    } catch (e) {
      debugPrint('  VideoCallService: Error hanging up: $e');
    }
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    debugPrint('  VideoCallService: Disposing...');

    try {
      await hangup();

      // Don't dispose renderers - they should be reusable for multiple calls
      // Only dispose them if you're completely done with the service
      debugPrint(
        '  VideoCallService: Disposed successfully (renderers kept for reuse)',
      );
    } catch (e) {
      debugPrint('  VideoCallService: Error disposing: $e');
    }
  }
}
