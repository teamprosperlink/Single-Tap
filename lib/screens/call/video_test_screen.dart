import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// Video Test Screen - For debugging camera and WebRTC issues
class VideoTestScreen extends StatefulWidget {
  const VideoTestScreen({super.key});

  @override
  State<VideoTestScreen> createState() => _VideoTestScreenState();
}

class _VideoTestScreenState extends State<VideoTestScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _isInitialized = false;
  bool _isFrontCamera = true;
  String _statusMessage = 'Not started';
  final List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  void _log(String message) {
    setState(() {
      _debugLogs.add('[${DateTime.now().toString().split(' ')[1]}] $message');
      _statusMessage = message;
    });
    debugPrint('VideoTest: $message');
  }

  Future<void> _initializeRenderer() async {
    try {
      _log('Initializing renderer...');
      await _localRenderer.initialize();
      setState(() {
        _isInitialized = true;
      });
      _log('  Renderer initialized successfully');
    } catch (e) {
      _log('  Renderer initialization error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      _log('Requesting camera permission...');
      final cameraStatus = await Permission.camera.request();
      _log('Camera permission: $cameraStatus');

      _log('Requesting microphone permission...');
      final micStatus = await Permission.microphone.request();
      _log('Microphone permission: $micStatus');

      if (cameraStatus.isGranted && micStatus.isGranted) {
        _log('  All permissions granted');
      } else {
        _log('  Permissions denied');
      }
    } catch (e) {
      _log('  Permission request error: $e');
    }
  }

  Future<void> _startCamera() async {
    try {
      _log('Starting camera...');

      // Request permissions first
      await _requestPermissions();

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

      _log('Requesting user media...');
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (_localStream == null) {
        throw Exception('getUserMedia returned null');
      }

      _log('  Got media stream: ${_localStream!.id}');
      _log('Audio tracks: ${_localStream!.getAudioTracks().length}');
      _log('Video tracks: ${_localStream!.getVideoTracks().length}');

      // Enable all tracks
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = true;
        _log('  Video track ${track.id} enabled: ${track.enabled}');
      }

      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = true;
        _log('  Audio track ${track.id} enabled: ${track.enabled}');
      }

      // Assign to renderer
      _log('Assigning stream to renderer...');
      _localRenderer.srcObject = _localStream;

      // Wait a bit for rendering
      await Future.delayed(const Duration(milliseconds: 200));

      if (_localRenderer.srcObject != null) {
        _log('  Camera started successfully!');
      } else {
        _log('  Failed to assign stream to renderer');
      }

      setState(() {});
    } catch (e, stackTrace) {
      _log('  Camera start error: $e');
      _log('Stack: ${stackTrace.toString().substring(0, 200)}...');
    }
  }

  Future<void> _stopCamera() async {
    try {
      _log('Stopping camera...');

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
      _log('  Camera stopped');
      setState(() {});
    } catch (e) {
      _log('  Stop camera error: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      _log('Switching camera...');
      await _stopCamera();
      _isFrontCamera = !_isFrontCamera;
      await Future.delayed(const Duration(milliseconds: 500));
      await _startCamera();
    } catch (e) {
      _log('  Switch camera error: $e');
    }
  }

  @override
  void dispose() {
    _stopCamera();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _localRenderer.srcObject != null;
    final videoTracks = _localRenderer.srcObject?.getVideoTracks().length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Test'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Video preview
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: Center(
                child: hasVideo && videoTracks > 0
                    ? RTCVideoView(
                        _localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: _isFrontCamera,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 80,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Status info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $_statusMessage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Renderer initialized: $_isInitialized',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Has video: $hasVideo (tracks: $videoTracks)',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Camera: ${_isFrontCamera ? "Front" : "Back"}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Control buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: const Icon(Icons.security),
                      label: const Text('Permissions'),
                    ),
                    ElevatedButton.icon(
                      onPressed: hasVideo ? _stopCamera : _startCamera,
                      icon: Icon(hasVideo ? Icons.stop : Icons.play_arrow),
                      label: Text(hasVideo ? 'Stop' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasVideo ? Colors.red : Colors.green,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: hasVideo ? _switchCamera : null,
                      icon: const Icon(Icons.flip_camera_android),
                      label: const Text('Switch'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _debugLogs.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Logs'),
                ),
              ],
            ),
          ),

          // Debug logs
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                reverse: true,
                itemCount: _debugLogs.length,
                itemBuilder: (context, index) {
                  final log = _debugLogs[_debugLogs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: log.contains(' ')
                            ? Colors.red
                            : log.contains(' ')
                            ? Colors.green
                            : Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
