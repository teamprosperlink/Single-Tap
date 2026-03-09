import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage floating call overlay (SingleTap-style PiP)
class FloatingCallService {
  static final FloatingCallService _instance = FloatingCallService._internal();
  factory FloatingCallService() => _instance;
  FloatingCallService._internal();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;
  Timer? _autoEndTimer;
  VoidCallback? _onEndCall;

  // Call info
  String? _callId;
  String? _userId;

  bool get isShowing => _isShowing;
  String? get callId => _callId;

  /// Show floating call overlay
  void showFloatingCall({
    required BuildContext context,
    required String callId,
    required String groupId,
    required String userId,
    required String groupName,
    required List<String> participantNames,
    required Function(BuildContext) onTap,
    required VoidCallback onEndCall,
  }) {
    if (_isShowing) {
      debugPrint('FloatingCallService: Overlay already showing');
      return;
    }

    _callId = callId;
    _userId = userId;
    _onEndCall = onEndCall;

    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingCallWidget(
        callId: callId,
        groupId: groupId,
        groupName: groupName,
        participantNames: participantNames,
        onTap: onTap,
        onEndCall: () {
          hide();
          onEndCall();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
    debugPrint('FloatingCallService: Overlay shown for call $callId');
  }

  /// Start auto-end timer for missed calls (no one joins within timeout)
  void startAutoEndTimer(int remainingSeconds) {
    _autoEndTimer?.cancel();
    if (remainingSeconds <= 0) remainingSeconds = 1;

    debugPrint(
      'FloatingCallService: Auto-end timer started ($remainingSeconds sec remaining)',
    );

    _autoEndTimer = Timer(Duration(seconds: remainingSeconds), () async {
      if (!_isShowing || _callId == null || _userId == null) return;

      try {
        // Query Firestore directly for active participants
        final activeSnapshot = await FirebaseFirestore.instance
            .collection('group_calls')
            .doc(_callId)
            .collection('participants')
            .where('isActive', isEqualTo: true)
            .get();

        final othersActive = activeSnapshot.docs
            .where((doc) => doc.id != _userId)
            .isNotEmpty;

        if (!othersActive) {
          debugPrint(
            'FloatingCallService: Auto-end - no one joined, ending call',
          );
          // Trigger end call (which hides overlay + cleans up WebRTC + updates Firestore)
          final endCall = _onEndCall;
          hide();
          endCall?.call();
        } else {
          debugPrint(
            'FloatingCallService: Auto-end - someone joined, keeping call',
          );
        }
      } catch (e) {
        debugPrint('FloatingCallService: Auto-end timer error: $e');
      }
    });
  }

  /// Hide and remove overlay
  void hide() {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
      _callId = null;
      _userId = null;
      _onEndCall = null;
      debugPrint('FloatingCallService: Overlay hidden');
    }
  }

  /// Dispose the service
  void dispose() {
    _autoEndTimer?.cancel();
    _autoEndTimer = null;
    hide();
  }
}

/// Floating call widget (SingleTap-style minimized call UI)
class FloatingCallWidget extends StatefulWidget {
  final String callId;
  final String groupId;
  final String groupName;
  final List<String> participantNames;
  final Function(BuildContext) onTap;
  final VoidCallback onEndCall;

  const FloatingCallWidget({
    super.key,
    required this.callId,
    required this.groupId,
    required this.groupName,
    required this.participantNames,
    required this.onTap,
    required this.onEndCall,
  });

  @override
  State<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends State<FloatingCallWidget> {
  int _duration = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _duration++;
        });
        _startTimer();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      right: 16,
      child: GestureDetector(
        onTap: () => widget.onTap(context),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00C853), // SingleTap green
                  Color(0xFF00E676),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Call icon with pulse animation
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),

                // Call info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // End call button
                GestureDetector(
                  onTap: widget.onEndCall,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30), // Red
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
