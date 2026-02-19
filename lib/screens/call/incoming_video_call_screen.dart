import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../models/user_profile.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../call/video_call_screen.dart';
import '../call/call_history_screen.dart';

/// SingleTap-style incoming video call screen
/// Shows caller's photo/name with accept/decline buttons
class IncomingVideoCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhoto;
  final String callerId;
  final VoidCallback? onCallAccepted;

  const IncomingVideoCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhoto,
    required this.callerId,
    this.onCallAccepted,
  });

  @override
  State<IncomingVideoCallScreen> createState() =>
      _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _callStatusSubscription;
  bool _isAnswering = false;
  bool _isNavigating = false;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _listenToCallStatus();
    _updateStatusToRinging();
    _playRingtone();
    HapticFeedback.heavyImpact();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _updateStatusToRinging() async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating status to ringing: $e');
    }
  }

  Future<void> _playRingtone() async {
    _startVibration();
    try {
      FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
      debugPrint(' Ringtone started playing');
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _startVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _stopRingtone() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await FlutterRingtonePlayer().stop();
      debugPrint('  Ringtone stopped');
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _firestore
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || _isNavigating || _isAnswering) return;

            final data = snapshot.data();
            if (data == null) {
              _stopRingtone();
              _safeNavigateBack();
              return;
            }

            final status = data['status'] as String?;
            debugPrint('  IncomingVideoCallScreen: Status changed to $status');

            if (status == 'ended' ||
                status == 'rejected' ||
                status == 'missed') {
              _stopRingtone();
              _safeNavigateBack();
            }
          },
          onError: (e) {
            debugPrint('Error listening to call status: $e');
          },
        );
  }

  void _safeNavigateBack() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    try {
      _stopRingtone();
    } catch (_) {}
    try {
      _pulseController.dispose();
    } catch (_) {}
    _callStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isAnswering || _isNavigating) return;
    debugPrint('  Accepting video call - callId=${widget.callId}');

    try {
      setState(() => _isAnswering = true);
    } catch (e) {
      debugPrint('setState error: $e');
    }
    _isNavigating = true;

    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('HapticFeedback error: $e');
    }

    try {
      await _stopRingtone();
    } catch (e) {
      debugPrint('Stop ringtone error: $e');
    }

    try {
      // Cancel status listener before updating to prevent race conditions
      _callStatusSubscription?.cancel();
      _callStatusSubscription = null;

      // Update call status to connected
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'connected',
        'acceptedAt': FieldValue.serverTimestamp(),
        'connectedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('  Call status updated to connected');

      if (!mounted) return;

      // Create fallback profile
      UserProfile callerProfile = UserProfile(
        uid: widget.callerId,
        id: widget.callerId,
        name: widget.callerName.isNotEmpty ? widget.callerName : 'Unknown',
        email: '',
        profileImageUrl: widget.callerPhoto,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Fetch caller profile from Firestore
      try {
        final callerDoc = await _firestore
            .collection('users')
            .doc(widget.callerId)
            .get();

        if (callerDoc.exists) {
          callerProfile = UserProfile.fromFirestore(callerDoc);
          debugPrint('  Using Firestore profile - ${callerProfile.name}');
        }
      } catch (e) {
        debugPrint('Error fetching profile: $e');
      }

      if (!mounted) return;

      // Call callback before navigation
      widget.onCallAccepted?.call();

      // Navigate to video call screen
      if (mounted && context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              callId: widget.callId,
              otherUser: callerProfile,
              isOutgoing: false,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('  Error accepting call: $e');
      debugPrint('Stack trace: $stackTrace');
      _isNavigating = false;
      if (mounted) {
        try {
          setState(() => _isAnswering = false);
        } catch (_) {}
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept call'),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isNavigating) return;
    HapticFeedback.mediumImpact();
    await _stopRingtone();

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _safeNavigateBack();
    } catch (e) {
      debugPrint('Error rejecting call: $e');
      _safeNavigateBack();
    }
  }

  void _showCallOptionsPopup() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundDarkSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Video Call Options',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 24),

            // Delete and Select buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Delete button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _deleteCallAndReject();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Select button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _openCallHistoryWithSelection();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist, color: Colors.blue, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Select',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

            const SizedBox(height: 24),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openCallHistoryWithSelection() async {
    await _stopRingtone();

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CallHistoryScreen(
            startInSelectionMode: true,
            initialSelectedCallId: widget.callId,
          ),
        ),
      );
    }
  }

  Future<void> _deleteCallAndReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkSecondary,
        title: const Text(
          'Delete this video call?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This call will be declined and removed from your call history.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _stopRingtone();

      try {
        await _firestore.collection('calls').doc(widget.callId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        _safeNavigateBack();
      } catch (e) {
        debugPrint('Error deleting call: $e');
        await _rejectCall();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(gradient: AppColors.splashGradient),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // "Incoming video call" text
                Text(
                  'Incoming video call',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Large caller avatar with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.6),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 90,
                          backgroundColor: const Color(0xFF2C2C2E),
                          backgroundImage: widget.callerPhoto != null
                              ? NetworkImage(widget.callerPhoto!)
                              : null,
                          child: widget.callerPhoto == null
                              ? Text(
                                  widget.callerName.isNotEmpty
                                      ? widget.callerName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // "Video call" subtitle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Video Call',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Accept and Decline buttons (SingleTap style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline button (Red)
                      _buildCallButton(
                        icon: Icons.call_end,
                        color: const Color(0xFFFF3B30),
                        label: 'Decline',
                        onTap: _rejectCall,
                      ),

                      // Accept button (Green)
                      _buildCallButton(
                        icon: Icons.videocam,
                        color: const Color(0xFF34C759),
                        label: 'Accept',
                        onTap: _acceptCall,
                        isLoading: _isAnswering,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // More options button
                TextButton.icon(
                  onPressed: _showCallOptionsPopup,
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  label: Text(
                    'More Options',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 35,
                      height: 35,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
