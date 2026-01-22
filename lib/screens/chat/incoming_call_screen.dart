import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../models/user_profile.dart';
import '../../models/message_model.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';
import '../call/voice_call_screen.dart';
// import '../call/video_call_screen.dart'; // Video calling disabled
import '../call/call_history_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhoto;
  final String callerId;
  final VoidCallback?
  onCallAccepted; // Callback to reset parent state before navigation

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhoto,
    required this.callerId,
    this.onCallAccepted,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _callStatusSubscription;
  bool _isAnswering = false;
  bool _isNavigating = false;
  String _callType = 'audio'; // Track call type (audio or video)

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _listenToCallStatus();
    _updateStatusToRinging();
    _playRingtone();
    HapticFeedback.heavyImpact();
    _fetchCallType(); // Fetch call type from Firestore
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

  // Fetch call type from Firestore
  Future<void> _fetchCallType() async {
    try {
      final callDoc = await _firestore
          .collection('calls')
          .doc(widget.callId)
          .get();
      if (callDoc.exists && mounted) {
        final type = callDoc.data()?['type'] ?? 'audio';
        setState(() {
          _callType = type;
        });
        debugPrint('  IncomingCallScreen: Call type fetched: $_callType');
      }
    } catch (e) {
      debugPrint('  IncomingCallScreen: Error fetching call type: $e');
    }
  }

  // Update call status to ringing so caller knows
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

  // Play ringtone sound
  Timer? _vibrationTimer;

  Future<void> _playRingtone() async {
    // Start vibration pattern
    _startVibration();

    try {
      // Play native ringtone instantly (no download needed)
      FlutterRingtonePlayer().playRingtone(
        looping: true,
        volume: 1.0,
        asAlarm: false,
      );
      debugPrint(' Ringtone started playing (native)');
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _startVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });
    // Immediate first vibration
    HapticFeedback.heavyImpact();
  }

  Future<void> _stopRingtone() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await FlutterRingtonePlayer().stop();
      debugPrint('🔔 Ringtone stopped');
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
            // IMPORTANT: Don't act on status changes if we're already accepting/navigating
            if (!mounted || _isNavigating || _isAnswering) return;

            final data = snapshot.data();
            if (data == null) {
              _stopRingtone();
              _safeNavigateBack();
              return;
            }

            final status = data['status'] as String?;
            debugPrint(
              '  IncomingCallScreen: Status changed to $status (isAnswering=$_isAnswering, isNavigating=$_isNavigating)',
            );

            // Close incoming call screen when caller cancels, call ends, or is rejected
            // BUT NOT when status is 'connected' - that means WE accepted the call
            if (status == 'ended' ||
                status == 'rejected' ||
                status == 'missed') {
              _stopRingtone();
              _safeNavigateBack();
            }
          },
          onError: (e) {
            debugPrint(
              '  IncomingCallScreen: Error listening to call status: $e',
            );
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
    debugPrint(
      '  IncomingCallScreen: _acceptCall started - callId=${widget.callId}',
    );

    // Check if user already has another active call (single call restriction)
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        final activeCallsQuery = await _firestore
            .collection('calls')
            .where('participants', arrayContains: currentUserId)
            .where('status', whereIn: ['calling', 'ringing', 'connected'])
            .limit(
              2,
            ) // Limit 2 to check if there's another call besides this one
            .get();

        // Filter out the current incoming call
        final otherActiveCalls = activeCallsQuery.docs
            .where((doc) => doc.id != widget.callId)
            .toList();

        if (otherActiveCalls.isNotEmpty) {
          // User already has another active call
          debugPrint(
            '⚠️ User already has another active call, cannot accept new call',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You already have an active call'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Reject this call automatically
          await _rejectCall();
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking active calls: $e');
      // Continue with call acceptance even if check fails
    }

    try {
      setState(() => _isAnswering = true);
    } catch (e) {
      debugPrint('  IncomingCallScreen: setState error: $e');
    }
    _isNavigating = true;

    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('  IncomingCallScreen: HapticFeedback error: $e');
    }

    try {
      await _stopRingtone();
    } catch (e) {
      debugPrint('  IncomingCallScreen: Stop ringtone error: $e');
    }

    try {
      // Cancel the status listener BEFORE updating status to prevent race conditions
      _callStatusSubscription?.cancel();
      _callStatusSubscription = null;
      debugPrint('  IncomingCallScreen: Cancelled status listener');

      // Update call status to connected so both sides know
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': 'connected',
        'acceptedAt': FieldValue.serverTimestamp(),
        'connectedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('  IncomingCallScreen: Updated call status to connected');

      if (!mounted) {
        debugPrint('  IncomingCallScreen: Not mounted after status update');
        return;
      }

      // Create fallback profile first (in case Firestore fetch fails)
      UserProfile callerProfile = UserProfile(
        uid: widget.callerId,
        id: widget.callerId,
        name: widget.callerName.isNotEmpty ? widget.callerName : 'Unknown',
        email: '',
        profileImageUrl: widget.callerPhoto,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

      // Try to fetch caller's user profile from Firestore
      try {
        final callerDoc = await _firestore
            .collection('users')
            .doc(widget.callerId)
            .get();
        debugPrint('  IncomingCallScreen: Fetched caller profile');

        if (callerDoc.exists) {
          callerProfile = UserProfile.fromFirestore(callerDoc);
          debugPrint(
            '  IncomingCallScreen: Using Firestore profile - ${callerProfile.name} (UID: ${callerProfile.uid})',
          );
        } else {
          debugPrint(
            '  IncomingCallScreen: Using fallback profile - ${widget.callerName}',
          );
        }
      } catch (e) {
        debugPrint(
          '  IncomingCallScreen: Error fetching profile, using fallback: $e',
        );
      }

      if (!mounted) {
        debugPrint('  IncomingCallScreen: Not mounted after fetching profile');
        return;
      }

      // Get call type from Firestore to determine which screen to navigate to
      final callDoc = await _firestore
          .collection('calls')
          .doc(widget.callId)
          .get();
      final callType = callDoc.data()?['type'] ?? 'audio';
      debugPrint(
        '  IncomingCallScreen: Call type is $callType, navigating to appropriate screen',
      );

      if (!mounted) {
        debugPrint('  IncomingCallScreen: Not mounted after getting call type');
        return;
      }

      // Navigate to appropriate call screen based on type
      if (mounted && context.mounted) {
        // CRITICAL: Call the callback BEFORE navigation to reset parent's _isShowingIncomingCall flag
        // This prevents the main_navigation_screen from being stuck with the flag set to true
        widget.onCallAccepted?.call();

        // Navigate to appropriate screen based on call type
        if (callType == 'video') {
          // Video calling functionality disabled - silently reject
          debugPrint(
            '  IncomingCallScreen: Video call rejected (feature disabled)',
          );
          await _rejectCall();
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;

          /* Original video call code (disabled)
          debugPrint(
            '  IncomingCallScreen: Navigating to VideoCallScreen with callerProfile: \${callerProfile.name} (\${callerProfile.uid})',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VideoCallScreen(
                callId: widget.callId,
                otherUser: callerProfile,
                isOutgoing: false,
              ),
            ),
          );
          */
        } else {
          debugPrint(
            '  IncomingCallScreen: Navigating to VoiceCallScreen with callerProfile: ${callerProfile.name} (${callerProfile.uid})',
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VoiceCallScreen(
                callId: widget.callId,
                otherUser: callerProfile,
                isOutgoing: false,
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('  IncomingCallScreen: Error accepting call: $e');
      debugPrint('  IncomingCallScreen: Stack trace: $stackTrace');
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

      //   REMOVED: Message saving is now handled by enhanced_chat_screen.dart
      // to prevent duplicate messages
      // await _sendMissedCallMessage();

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
              'Call Options',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 24),

            // Delete and Select buttons in a row
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

                  // Select button (navigate to call history with selection)
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
    // Reject the call first, then navigate to call history
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
      // Navigate to call history screen with selection mode enabled
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
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDarkSecondary,
        title: const Text(
          'Delete this call?',
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
        // Delete the call document
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
        // Fall back to just rejecting if delete fails
        await _rejectCall();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(gradient: AppColors.splashGradient),
          ),

          // Blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: AppColors.blackAlpha(alpha: 0.3)),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),

                // Incoming call text
                Text(
                  'Incoming Call',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 40),

                // Animated caller avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.vibrantGreen.withValues(
                              alpha: 0.5,
                            ),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.vibrantGreen.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: AppColors.backgroundDarkTertiary,
                          backgroundImage: widget.callerPhoto != null
                              ? NetworkImage(widget.callerPhoto!)
                              : null,
                          child: widget.callerPhoto == null
                              ? Text(
                                  widget.callerName.isNotEmpty
                                      ? widget.callerName[0].toUpperCase()
                                      : 'U',
                                  style: AppTextStyles.displayLarge.copyWith(
                                    fontSize: 56,
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
                  style: AppTextStyles.displayMedium.copyWith(fontSize: 32),
                ),

                const SizedBox(height: 8),

                // Call type
                Text(
                  _callType == 'video' ? 'Video Call' : 'Voice Call',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),

                const Spacer(),

                // Call action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reject button
                      _buildActionButton(
                        icon: Icons.call_end_rounded,
                        color: AppColors.error,
                        label: 'Decline',
                        onTap: _rejectCall,
                      ),

                      // Accept button
                      _buildActionButton(
                        icon: _callType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: AppColors.vibrantGreen,
                        label: 'Accept',
                        onTap: _acceptCall,
                        isLoading: _isAnswering,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // More options button (shows popup with select/delete)
                TextButton.icon(
                  onPressed: _showCallOptionsPopup,
                  icon: Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondaryDark,
                  ),
                  label: Text(
                    'More Options',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
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
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: AppColors.textPrimaryDark,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Icon(icon, color: AppColors.textPrimaryDark, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
