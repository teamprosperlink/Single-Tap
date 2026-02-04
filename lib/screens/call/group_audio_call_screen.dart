import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/config/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/other services/group_voice_call_service.dart';
import '../../services/floating_call_service.dart';
import '../../widgets/floating_particles.dart';

/// WhatsApp-style Group Audio Call Screen
/// Supports multiple participants with audio-only conference call
class GroupAudioCallScreen extends StatefulWidget {
  final String callId;
  final String groupId;
  final String userId;
  final String userName;
  final String groupName;
  final List<Map<String, dynamic>>
  participants; // List of {userId, name, photoUrl}

  const GroupAudioCallScreen({
    super.key,
    required this.callId,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.groupName,
    required this.participants,
  });

  @override
  State<GroupAudioCallScreen> createState() => _GroupAudioCallScreenState();
}

class _GroupAudioCallScreenState extends State<GroupAudioCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupVoiceCallService _groupVoiceCallService = GroupVoiceCallService();

  Timer? _callTimer;
  Timer? _missedCallTimer;
  int _callDuration = 0;
  int _callWaitTime =
      0; // Track how long waiting for first join (max 39 seconds)
  DateTime? _callStartTime;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isEndingCall = false;
  bool _isMinimizing = false; // Track if minimizing (not ending) the call

  // Track participant info: participantId -> {name, photoUrl, isActive, isMuted, joinedAt}
  final Map<String, Map<String, dynamic>> _participantInfo = {};
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('  GroupAudioCallScreen: initState - callId=${widget.callId}');

    // Initialize call start time
    _callStartTime = DateTime.now();

    // CRITICAL FIX: Deduplicate participants by userId before storing
    // This prevents duplicate participant cards in the UI
    final seenUserIds = <String>{};
    int duplicateCount = 0;

    for (var participant in widget.participants) {
      final userId = participant['userId'] as String;

      if (!seenUserIds.contains(userId)) {
        // First time seeing this userId - add to map
        seenUserIds.add(userId);
        final isActive = userId == widget.userId; // Current user is active
        _participantInfo[userId] = {
          'name': participant['name'] ?? 'Unknown',
          'photoUrl': participant['photoUrl'],
          'isActive': isActive,
          'joinedAt': isActive ? DateTime.now() : null,
          'isMuted': false,
        };
      } else {
        // Duplicate userId found - skip it
        duplicateCount++;
        debugPrint(
          '  Skipping duplicate participant: $userId (${participant['name']})',
        );
      }
    }

    if (duplicateCount > 0) {
      debugPrint(
        '🔧 Removed $duplicateCount duplicate participants from ${widget.participants.length} total',
      );
    }

    debugPrint('  Final unique participants: ${_participantInfo.keys.length}');

    _listenToParticipants();
    _startCallTimer();
    _startMissedCallTimer(); // Start 39-second timeout for missed call
    _updateCallStatus('active');

    // Delay WebRTC initialization to avoid conflicts with screen setup
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeWebRTC();
      }
    });
  }

  Future<void> _initializeWebRTC() async {
    try {
      debugPrint('  GroupAudioCallScreen: Initializing WebRTC...');

      // Set up callbacks
      _groupVoiceCallService.onParticipantJoined =
          (participantId, participantName) {
            debugPrint(
              '  Participant joined WebRTC: $participantName ($participantId)',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$participantName joined the call'),
                  backgroundColor: const Color(0xFF25D366),
                  duration: const Duration(seconds: 2),
                ),
              );

              // Send Firestore notification in background (non-blocking)
              _sendParticipantNotification(
                participantId: participantId,
                participantName: participantName,
                action: 'joined',
              );
            }
          };

      _groupVoiceCallService.onParticipantLeft = (participantId) {
        debugPrint('  Participant left WebRTC: $participantId');

        // Show notification that participant left
        final participantName = _participantInfo[participantId]?['name'] as String? ?? 'Someone';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$participantName left the call'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );

          // Send Firestore notification in background (non-blocking)
          _sendParticipantNotification(
            participantId: participantId,
            participantName: participantName,
            action: 'left',
          );
        }
      };

      _groupVoiceCallService.onError = (message) {
        debugPrint('  WebRTC error: $message');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call error: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      };

      // Join the WebRTC call
      try {
        final success = await _groupVoiceCallService.joinCall(
          widget.callId,
          widget.userId,
        );

        if (success) {
          debugPrint('  WebRTC call joined successfully');
          setState(() {
            _isMuted = _groupVoiceCallService.isMuted;
            _isSpeakerOn = _groupVoiceCallService.isSpeakerOn;
          });
        } else {
          debugPrint('  Failed to join WebRTC call');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to initialize audio. Check microphone permissions.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('  Error joining WebRTC call: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join call: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('  Error initializing WebRTC: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize WebRTC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send participant join/leave notification to other participants (non-blocking)
  void _sendParticipantNotification({
    required String participantId,
    required String participantName,
    required String action, // 'joined' or 'left'
  }) {
    // Run in background without blocking
    Future.microtask(() async {
      try {
        final callDoc = await _firestore
            .collection('group_calls')
            .doc(widget.callId)
            .get();
        if (callDoc.exists) {
          final participants = callDoc.data()?['participants'] as List? ?? [];
          for (var pId in participants) {
            if (pId != widget.userId && pId != participantId) {
              // Send notification to other participants
              await _firestore.collection('notifications').add({
                'userId': pId,
                'senderId': participantId,
                'senderName': participantName,
                'type': 'call_participant_$action',
                'title': 'Call Update',
                'body': '$participantName $action the call',
                'data': {
                  'callId': widget.callId,
                  'groupId': widget.groupId,
                },
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      } catch (e) {
        debugPrint('  Error sending $action notification: $e');
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _missedCallTimer?.cancel();
    _participantsSubscription?.cancel();

    // Clean up WebRTC - but only if NOT minimizing
    // When minimizing, we want to keep the call running in background
    if (!_isMinimizing) {
      debugPrint('GroupAudioCallScreen: Disposing - leaving call');
      _groupVoiceCallService.leaveCall();
    } else {
      debugPrint('GroupAudioCallScreen: Disposing - keeping call active (minimized)');
    }

    super.dispose();
  }

  void _listenToParticipants() {
    _participantsSubscription = _firestore
        .collection('group_calls')
        .doc(widget.callId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;

          // Fetch participant details for new participants
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final userId = data['userId'] as String;

            if (!_participantInfo.containsKey(userId)) {
              // New participant - fetch their details from users collection
              try {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(userId)
                    .get();
                if (userDoc.exists && mounted) {
                  final userData = userDoc.data();
                  final isActive = data['isActive'] == true;
                  setState(() {
                    _participantInfo[userId] = {
                      'name': userData?['name'] ?? 'Unknown',
                      'photoUrl': userData?['photoUrl'],
                      'isActive': isActive,
                      'joinedAt': isActive ? DateTime.now() : null,
                      'isMuted': false, // Default to unmuted
                    };
                  });
                  debugPrint(
                    '  Fetched participant details: ${userData?['name']} ($userId)',
                  );
                }
              } catch (e) {
                debugPrint('  Error fetching participant $userId: $e');
              }
            } else {
              // Existing participant - update active status
              final wasActive = _participantInfo[userId]!['isActive'] as bool? ?? false;
              final isNowActive = data['isActive'] == true;

              if (mounted) {
                setState(() {
                  _participantInfo[userId]!['isActive'] = isNowActive;

                  // Track join time when participant becomes active
                  if (!wasActive && isNowActive) {
                    _participantInfo[userId]!['joinedAt'] = DateTime.now();
                  }
                });
              }
            }
          }

          // Check if any other participants are active
          final othersActive = _participantInfo.entries
              .where(
                (entry) =>
                    entry.key != widget.userId &&
                    entry.value['isActive'] == true,
              )
              .isNotEmpty;

          if (othersActive && _callDuration == 0) {
            // First person joined, start the timer
            debugPrint('  First participant joined, starting call timer');
          }

          // AUTO-END DETECTION: Check if should auto-end
          final totalParticipants = _participantInfo.length;
          final activeCount = _participantInfo.entries
              .where((entry) => entry.value['isActive'] == true)
              .length;

          bool shouldAutoEnd = false;
          String autoEndReason = '';

          // 2-PERSON CALL: If only 2 people and one leaves
          if (totalParticipants == 2 && activeCount == 1 && !_isEndingCall) {
            shouldAutoEnd = true;
            autoEndReason = '2-person call: one person left';
          }
          // ALL LEFT: If all other participants disconnected
          else if (!othersActive && _callDuration > 0 && !_isEndingCall) {
            shouldAutoEnd = true;
            autoEndReason = 'all participants disconnected';
          }

          // AUTO-END: Do direct cleanup without calling _endCall from listener
          if (shouldAutoEnd) {
            debugPrint('  AUTO-END: $autoEndReason');
            _isEndingCall = true; // Set flag immediately

            // Cancel this listener to prevent further callbacks
            _participantsSubscription?.cancel();
            _callTimer?.cancel();
            _missedCallTimer?.cancel();

            // Leave WebRTC
            try {
              await _groupVoiceCallService.leaveCall();
              await _updateCallStatus('ended');
              await _updateParticipantStatus(false);
            } catch (e) {
              debugPrint('  AUTO-END error: $e');
            }

            // Navigate back
            if (mounted) {
              Navigator.pop(context);
            }
          }

          // CALLER-ENDED EARLY: If caller leaves before anyone joins, end call immediately
          try {
            final callDoc = await _firestore
                .collection('group_calls')
                .doc(widget.callId)
                .get();

            if (callDoc.exists && !_isEndingCall) {
              final callData = callDoc.data();
              final callerId = callData?['callerId'] as String?;

              // Check if caller has left and no one else joined yet
              if (callerId != null && _callDuration == 0) {
                final callerData = _participantInfo[callerId];
                final callerActive = callerData?['isActive'] == true;

                // If caller left and no one else is active (except maybe current user who is also caller)
                if (!callerActive && !othersActive) {
                  debugPrint(
                    '  Caller ($callerId) left before anyone joined. Ending call immediately...',
                  );
                  // Mark call as ended in Firestore first
                  try {
                    await _updateCallStatus('ended');
                  } catch (e) {
                    debugPrint('  Error updating call status: $e');
                  }
                  // Call _endCall for proper cleanup
                  if (mounted) {
                    await _endCall();
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('  Error checking caller status: $e');
          }
        });
  }

  void _startCallTimer() {
    // Timer runs but only increments when at least one other person (not current user) is active
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check if anyone else (excluding current user) is active
        final othersActive = _participantInfo.entries
            .where(
              (entry) =>
                  entry.key != widget.userId && entry.value['isActive'] == true,
            )
            .isNotEmpty;

        if (othersActive) {
          setState(() => _callDuration++);
        }
      }
    });
  }

  void _startMissedCallTimer() {
    // Start a 39-second timeout - if no one joins, mark as missed call
    _missedCallTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!mounted) return;

      // Check if anyone else (excluding current user) is active
      final othersActive = _participantInfo.entries
          .where(
            (entry) =>
                entry.key != widget.userId && entry.value['isActive'] == true,
          )
          .isNotEmpty;

      _callWaitTime++;

      // If someone joined, cancel the missed call timer
      if (othersActive) {
        debugPrint('  Participant joined - cancelling missed call timer');
        _missedCallTimer?.cancel();
        return;
      }

      // If 39 seconds passed without anyone joining, end call as missed
      if (_callWaitTime >= 39) {
        debugPrint(
          '  No one joined within 39 seconds - marking as missed call',
        );
        _missedCallTimer?.cancel();

        // Hide floating overlay if showing
        if (FloatingCallService().isShowing) {
          FloatingCallService().hide();
        }

        // End the call (without calling _endCall which would navigate)
        try {
          // Leave WebRTC call
          await _groupVoiceCallService.leaveCall();

          await _updateParticipantStatus(false);
          await _updateCallStatus('ended');

          // Update system message as missed call
          final callDoc = await _firestore
              .collection('group_calls')
              .doc(widget.callId)
              .get();
          if (callDoc.exists) {
            final callData = callDoc.data();
            final systemMessageId = callData?['systemMessageId'] as String?;
            final groupId = callData?['groupId'] as String?;

            if (systemMessageId != null && groupId != null) {
              await _firestore
                  .collection('conversations')
                  .doc(groupId)
                  .collection('messages')
                  .doc(systemMessageId)
                  .update({
                    'callDuration': 0,
                    'participantCount': 0,
                    'text': 'Missed call',
                  });
            }
          }

          // Navigate back
          if (mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          debugPrint('  Error marking call as missed: $e');
        }
      }
    });
  }

  Future<void> _updateCallStatus(String status) async {
    try {
      debugPrint('  Updating call status to: $status for callId: ${widget.callId}');
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'status': status,
        if (status == 'ended') 'endedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('   Call status updated successfully');
    } catch (e) {
      debugPrint('   Error updating call status: $e');
      // Try to set status using set with merge instead of update
      try {
        await _firestore.collection('group_calls').doc(widget.callId).set({
          'status': status,
          if (status == 'ended') 'endedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('   Call status set via merge');
      } catch (e2) {
        debugPrint('    Failed to set call status via merge: $e2');
      }
    }
  }

  Future<void> _updateParticipantStatus(bool isActive) async {
    try {
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(widget.userId)
          .update({'isActive': isActive});
    } catch (e) {
      debugPrint('  Error updating participant status: $e');
    }
  }

  /// Update Firestore in background without blocking navigation
  void _updateFirestoreInBackground() {
    Future.microtask(() async {
      try {
        // Update participant status to false (leave the call)
        await _updateParticipantStatus(false);
        debugPrint(' Background: Participant status updated');

        // Safety check: if no active participants remain, mark call as ended
        try {
          final activeSnapshot = await _firestore
              .collection('group_calls')
              .doc(widget.callId)
              .collection('participants')
              .where('isActive', isEqualTo: true)
              .get();
          if (activeSnapshot.docs.isEmpty) {
            await _updateCallStatus('ended');
            debugPrint(' Background: No active participants - call marked as ENDED');
          }
        } catch (e) {
          debugPrint(' Background: Error checking active participants: $e');
        }

        // Update system message with call duration and participant count
        final callDoc = await _firestore
            .collection('group_calls')
            .doc(widget.callId)
            .get();
        if (callDoc.exists) {
          final callData = callDoc.data();
          final systemMessageId = callData?['systemMessageId'] as String?;
          final groupId = callData?['groupId'] as String?;

          // Get ALL participants who joined (including current user)
          final joinedParticipantIds = _participantInfo.entries
              .where(
                (entry) =>
                    entry.value['isActive'] == true ||
                    entry.value['wasActive'] == true,
              )
              .map((entry) => entry.key)
              .toList();

          // Count OTHER participants who joined (exclude current user for message)
          final activeParticipantCount = joinedParticipantIds
              .where((id) => id != widget.userId)
              .length;

          // Save joined participants info to the group_calls document
          await _firestore
              .collection('group_calls')
              .doc(widget.callId)
              .update({
                'joinedParticipants': joinedParticipantIds,
                'joinedCount': joinedParticipantIds.length,
                'totalMembers': _participantInfo.length,
              });
          debugPrint(' Background: Saved joinedParticipants: $joinedParticipantIds');

          if (systemMessageId != null && groupId != null) {
            // Update the system message with call details
            await _firestore
                .collection('conversations')
                .doc(groupId)
                .collection('messages')
                .doc(systemMessageId)
                .update({
                  'callDuration': _callDuration,
                  'participantCount': activeParticipantCount,
                  'text': _callDuration > 0
                      ? 'Voice call • ${_formatDuration(_callDuration)} • $activeParticipantCount joined'
                      : 'Missed call',
                });
            debugPrint(' Background: System message updated');
          }
        }
      } catch (e) {
        debugPrint(' Background: Error updating Firestore: $e');
      }
    });
  }

  Future<void> _toggleMute() async {
    await _groupVoiceCallService.toggleMute();
    setState(() => _isMuted = _groupVoiceCallService.isMuted);
    debugPrint('  Mute toggled: $_isMuted');
  }

  Future<void> _toggleSpeaker() async {
    await _groupVoiceCallService.toggleSpeaker();
    setState(() => _isSpeakerOn = _groupVoiceCallService.isSpeakerOn);
    debugPrint('🔊 Speaker toggled: $_isSpeakerOn');
  }

  Future<void> _endCall() async {
    debugPrint(' _endCall: Method called, _isEndingCall=$_isEndingCall');

    // Double-check guard for rapid clicks
    if (_isEndingCall) {
      debugPrint(' _endCall: Already ending, ignoring duplicate call');
      return;
    }

    // Set flag immediately to block rapid clicks
    _isEndingCall = true;
    debugPrint(' _endCall: Flag set to true');

    // CRITICAL: Cancel participant listener FIRST to prevent interference
    _participantsSubscription?.cancel();
    _participantsSubscription = null;
    debugPrint(' _endCall: Participant listener cancelled');

    // Cancel timers
    _callTimer?.cancel();
    _missedCallTimer?.cancel();
    debugPrint(' _endCall: Timers cancelled');

    // Hide floating overlay if showing
    if (FloatingCallService().isShowing) {
      FloatingCallService().hide();
      debugPrint(' _endCall: Floating overlay hidden');
    }

    try {
      debugPrint(' _endCall: Starting WebRTC cleanup...');
      // Leave WebRTC call
      await _groupVoiceCallService.leaveCall();
      debugPrint(' _endCall: WebRTC call left');

      // Query Firestore directly for active participants (not stale local data)
      // This is critical when called from floating overlay after screen is disposed
      bool othersActive = false;
      try {
        final activeSnapshot = await _firestore
            .collection('group_calls')
            .doc(widget.callId)
            .collection('participants')
            .where('isActive', isEqualTo: true)
            .get();
        othersActive = activeSnapshot.docs
            .where((doc) => doc.id != widget.userId)
            .isNotEmpty;
      } catch (e) {
        debugPrint(' _endCall: Error querying active participants: $e');
      }

      debugPrint(' _endCall: othersActive=$othersActive, callDuration=$_callDuration');

      // Always mark call as ended if no one else is active
      // This ensures the banner disappears when caller leaves
      if (!othersActive) {
        debugPrint(' _endCall: No others active - marking call as ENDED');
        try {
          await _updateCallStatus('ended');
          debugPrint(' _endCall:   Status updated to ENDED');
        } catch (e) {
          debugPrint(' _endCall:   Error updating status: $e');
        }
      } else {
        debugPrint(' _endCall: Others still active - keeping call active');
      }

      // Update Firestore in background (non-blocking)
      _updateFirestoreInBackground();

    } catch (e) {
      debugPrint(' _endCall: ERROR - $e');
    }

    // Navigate back immediately (don't wait for Firestore)
    debugPrint(' _endCall: Navigating back...');
    if (mounted) {
      Navigator.pop(context);
      debugPrint(' _endCall:   Navigation completed');
    } else {
      debugPrint('  _endCall:   Not mounted, skipping navigation');
    }
  }

  /// Minimize call to floating overlay (WhatsApp-style PiP)
  void _minimizeCall() {
    debugPrint('GroupAudioCallScreen: Minimizing call...');

    // Mark as minimizing so dispose doesn't leave the call
    _isMinimizing = true;

    // Get participant names for the floating UI
    final participantNames = _participantInfo.values
        .where((info) => info['userId'] !=   widget.userId)
        .map((info) => info['name'] as String)
        .toList();

    // Store call info for later use in callback
    final callId = widget.callId;
    final groupId = widget.groupId;
    final userId = widget.userId;
    final userName = widget.userName;
    final groupName = widget.groupName;
    final participants = widget.participants;

    // Show floating overlay
    FloatingCallService().showFloatingCall(
      context: context,
      callId: callId,
      groupId: groupId,
      userId: userId,
      groupName: groupName,
      participantNames: participantNames,
      onTap: (overlayContext) {
        // Expand back to full screen
        debugPrint('FloatingCall: Tapped - expanding to full screen');
        FloatingCallService().hide();

        // Navigate back to full screen call UI using overlay's context
        Navigator.push(
          overlayContext,
          MaterialPageRoute(
            builder: (context) => GroupAudioCallScreen(
              callId: callId,
              groupId: groupId,
              userId: userId,
              userName: userName,
              groupName: groupName,
              participants: participants,
            ),
          ),
        );
      },
      onEndCall: () async {
        // End call from floating overlay
        debugPrint('FloatingCall: End call pressed');
        await _endCall();
      },
    );

    // If no one has joined yet, continue the 39-sec missed call timer in floating overlay
    if (_callDuration == 0) {
      final remainingSeconds = 39 - _callWaitTime;
      if (remainingSeconds > 0) {
        FloatingCallService().startAutoEndTimer(remainingSeconds);
        debugPrint('GroupAudioCallScreen: Auto-end timer transferred to floating overlay ($remainingSeconds sec)');
      }
    }

    // Pop this screen (but call continues in background)
    if (mounted) {
      Navigator.pop(context);
    }

    debugPrint('GroupAudioCallScreen: Call minimized to floating overlay');
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatCallDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dayName;
    if (callDate == today) {
      dayName = 'Today';
    } else if (callDate == yesterday) {
      dayName = 'Yesterday';
    } else {
      // Format as "Mon, Jan 15"
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dayName =
          '${days[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}';
    }

    // Format time as HH:MM
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    return '$dayName • $time';
  }

  @override
  Widget build(BuildContext context) {
    // Count active participants excluding current user
    final activeParticipants = _participantInfo.entries
        .where(
          (entry) =>
              entry.key != widget.userId && entry.value['isActive'] == true,
        )
        .map((entry) => entry.value)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: false,
      body: Stack(
        children: [
          // Background Image (same as home screen)
          Positioned.fill(
            child: Image.asset(
              'assets/logo/home_background.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),

          // Blur effect with dark overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),

          // Floating particles
          const Positioned.fill(child: FloatingParticles(particleCount: 12)),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header (buttons only)
                _buildHeader(),

                const SizedBox(height: 20),

                // Profile circle
                _buildCurrentUserProfile(),

                const SizedBox(height: 16),

                // Group name
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_participantInfo.length} ${_participantInfo.length == 1 ? 'participant' : 'participants'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 20),

                // Call duration - only show when someone has joined
                if (activeParticipants.isNotEmpty)
                  Text(
                    _formatDuration(_callDuration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                if (activeParticipants.isNotEmpty) const SizedBox(height: 8),

                // Call status - only show when someone has joined
                if (activeParticipants.isNotEmpty)
                  Text(
                    '${activeParticipants.length} ${activeParticipants.length == 1 ? 'person' : 'people'} joined',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),

                const SizedBox(height: 16),

                // Participants grid
                _buildParticipantsGrid(activeParticipants),

                const Spacer(flex: 3),

                // Controls
                _buildControls(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Minimize button (WhatsApp-style)
          Positioned(
            left: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
                onPressed: _minimizeCall,
                tooltip: 'Minimize',
                padding: EdgeInsets.zero,
              ),
            ),
          ),

          // Center: empty spacer to keep Stack height for buttons
          const SizedBox(height: 40),

          // Right: Add participant button
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.person_add_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _showAddParticipantDialog,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserProfile() {
    final currentUserPhoto =
        _participantInfo[widget.userId]?['photoUrl'] as String?;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: currentUserPhoto != null && currentUserPhoto.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: currentUserPhoto,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person, size: 40, color: Colors.white),
      ),
    );
  }

  Future<void> _showAddParticipantDialog() async {
    try {
      // Fetch all group members
      final groupDoc = await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .get();

      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final allMemberIds = List<String>.from(groupData['participants'] ?? []);

      // Separate pending participants (not yet connected)
      final pendingParticipantIds = _participantInfo.entries
          .where((entry) => entry.value['isActive'] != true)
          .map((entry) => entry.key)
          .toSet();

      // Get new members (not in call at all)
      final newMemberIds = allMemberIds
          .where((id) => !_participantInfo.keys.contains(id))
          .toList();

      // Fetch pending participant details (for re-invite)
      final pendingDetails = <Map<String, dynamic>>[];
      for (final memberId in pendingParticipantIds) {
        final memberInfo = _participantInfo[memberId];
        if (memberInfo != null) {
          pendingDetails.add({
            'userId': memberId,
            'name': memberInfo['name'] ?? 'Unknown',
            'photoUrl': memberInfo['photoUrl'],
            'isPending': true,
          });
        }
      }

      // Fetch new member details
      final newMemberDetails = <Map<String, dynamic>>[];
      for (final memberId in newMemberIds) {
        final userDoc = await _firestore
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          newMemberDetails.add({
            'userId': memberId,
            'name': userData['name'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
            'isPending': false,
          });
        }
      }

      if (pendingDetails.isEmpty && newMemberDetails.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All group members are already in the call'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Combine: pending first, then new members
      final allMembers = [...pendingDetails, ...newMemberDetails];

      // Show bottom sheet with available members
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Add Participants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Member list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: allMembers.length,
                    itemBuilder: (context, index) {
                      final member = allMembers[index];
                      final isPending = member['isPending'] as bool? ?? false;

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: member['photoUrl'] != null
                                  ? CachedNetworkImageProvider(
                                      member['photoUrl'],
                                    )
                                  : null,
                              backgroundColor: AppColors.iosBlue.withValues(
                                alpha: isPending ? 0.15 : 0.2,
                              ),
                              child: member['photoUrl'] == null
                                  ? Text(
                                      (member['name'] as String)[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        title: Text(
                          member['name'],
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: isPending ? 0.6 : 1.0,
                            ),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: isPending
                            ? const Text(
                                'Ringing...',
                                style: TextStyle(
                                  color: Color(0xFFFF9500),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            isPending ? 'Re-call' : 'Add',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _addParticipantToCall(member);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing add participant dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addParticipantToCall(Map<String, dynamic> member) async {
    final memberId = member['userId'] as String;
    final memberName = member['name'] as String? ?? 'Unknown';

    try {
      debugPrint('    Re-calling participant: $memberName ($memberId)');

      // Step 1: Ensure participant document exists in subcollection
      await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .collection('participants')
          .doc(memberId)
          .set({
            'userId': memberId,
            'name': memberName,
            'photoUrl': member['photoUrl'],
            'isActive': false, // Will become true when they accept
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('    Participant document created/updated in subcollection');

      // Step 2: Add participant to main call document participants array
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'participants': FieldValue.arrayUnion([memberId]),
      });

      debugPrint('    Participant added to call participants array');

      final callerPhoto = await _getCallerPhoto(widget.userId);
      debugPrint('  📸 Caller photo for notification: $callerPhoto');

      // Step 4: Send notification - this will trigger CallKit UI
      await NotificationService().sendNotificationToUser(
        userId: memberId,
        title: 'Incoming Group Audio Call',
        body: '${widget.userName} added you to ${widget.groupName}',
        type: 'group_audio_call',
        data: {
          'callId': widget.callId,
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'callerId': widget.userId,
          'callerName': widget.userName,
          'callerPhoto': callerPhoto,
          'isVideo': false,
        },
      );

      debugPrint('    Notification sent to $memberName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-called $memberName'),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('   Error adding participant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add $memberName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper method to get caller's photo URL
  Future<String?> _getCallerPhoto(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['photoUrl'] as String?;
    } catch (e) {
      debugPrint('  Error fetching caller photo: $e');
      return null;
    }
  }

  Widget _buildParticipantsGrid(List<Map<String, dynamic>> activeParticipants) {
    // Separate participants into connected and pending
    final connectedParticipants = _participantInfo.entries
        .where(
          (entry) =>
              entry.key != widget.userId && // Exclude current user
              entry.value['isActive'] == true,
        )
        .map((entry) {
          return {
            'userId': entry.key,
            'name': entry.value['name'],
            'photoUrl': entry.value['photoUrl'],
            'isActive': true,
          };
        })
        .toList();

    // Show waiting message when no one has joined yet
    if (connectedParticipants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for others to join...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
      );
    }

    // Show only other participants (not current user)
    return SingleChildScrollView(
      child: Column(
        children: [
          // Only show other connected participants
          if (connectedParticipants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: connectedParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = connectedParticipants[index];
                      return _buildParticipantCard(
                        participant['name'] ?? 'Unknown',
                        participant['photoUrl'],
                        false, // isCurrentUser
                        true, // isActive
                        isLarge: false, // Small member cards
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(
    String name,
    String? photoUrl,
    bool isCurrentUser,
    bool isActive, {
    bool isLarge = true,
  }) {
    // CRITICAL FIX: Determine correct status text
    // - Caller (isCurrentUser=true, viewing OTHER participants who are not active) should see: "Ringing..."
    // - Other participants (isCurrentUser=false, not active) should display: "Ringing..."
    // - Active participants should show: "Connected" or "Muted"
    // NOTE: This card shows OTHER participants, NOT the current user themselves

    String statusText;
    Color statusColor;

    if (!isActive) {
      // Participant hasn't joined yet - always show "Ringing..."
      statusText = 'Ringing...';
      statusColor = const Color(0xFFFF9500); // WhatsApp orange
    } else if (_isMuted && isCurrentUser) {
      // This shouldn't happen since isCurrentUser check in grid excludes caller
      // But keeping as fallback
      statusText = 'Muted';
      statusColor = const Color(0xFFFF3B30); // WhatsApp red
    } else {
      // Participant is active/connected
      statusText = 'Connected';
      statusColor = const Color(0xFF25D366); // WhatsApp green
    }

    // Size adjustments based on isLarge flag
    final avatarSize = isLarge ? 80.0 : 50.0;
    final avatarBorderWidth = isLarge ? 3.0 : 2.5;
    final namefontSize = isLarge ? 16.0 : 12.0;
    final statusFontSize = isLarge ? 11.0 : 9.0;
    final containerBorderRadius = isLarge ? 16.0 : 12.0;
    final containerPadding = isLarge
        ? const EdgeInsets.all(24)
        : const EdgeInsets.all(12);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isCurrentUser
              ? [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)]
              : [const Color(0xFF2F2F2F), const Color(0xFF1F1F1F)],
        ),
        borderRadius: BorderRadius.circular(containerBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: containerPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile picture
            Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF25D366) // WhatsApp green
                        : Colors.white.withValues(alpha: 0.25),
                    width: avatarBorderWidth,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Profile image
                    ClipOval(
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.iosBlue.withValues(alpha: 0.2),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.iosBlue.withValues(alpha: 0.2),
                                child: Center(
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.iosBlue.withValues(alpha: 0.2),
                              child: Center(
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Waveform overlay when active/speaking
                    if (isActive && !_isMuted)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                          child: _buildMiniWaveform(),
                        ),
                      ),

                    // Mute status indicator (WhatsApp style)
                    if (_isMuted && isCurrentUser)
                      Positioned(
                        bottom: isLarge ? 8 : 4,
                        right: isLarge ? 8 : 4,
                        child: Container(
                          padding: EdgeInsets.all(isLarge ? 6 : 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30), // Red for muted
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic_off,
                            color: Colors.white,
                            size: isLarge ? 16 : 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Name
            Text(
              isCurrentUser ? 'You' : name,
              style: TextStyle(
                color: Colors.white,
                fontSize: namefontSize,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 4),

            // Status indicator
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: statusFontSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final heights = [3.0, 6.0, 4.0, 8.0, 5.0, 7.0, 4.0, 6.0];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 2,
          height: heights[index],
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366), // WhatsApp green
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            onTap: _toggleMute,
            backgroundColor: _isMuted
                ? const Color(0xFFFF3B30) // WhatsApp red when muted
                : const Color(0xFF3A3A3A), // Dark gray when unmuted
            iconColor: Colors.white,
          ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end_rounded,
            onTap: _isEndingCall
                ? null
                : () {
                    debugPrint('  END CALL BUTTON TAPPED');
                    _endCall();
                  },
            backgroundColor: const Color(0xFFFF3B30), // WhatsApp red
            iconColor: Colors.white,
            size: 68,
          ),

          // Speaker button
          _buildControlButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            onTap: _toggleSpeaker,
            backgroundColor: const Color(0xFF3A3A3A), // Dark gray
            iconColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              debugPrint('🔘 Control button tapped: $icon');
              onTap();
            },
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: isDisabled,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDisabled
              ? backgroundColor.withValues(alpha: 0.5)
              : backgroundColor,
          shape: BoxShape.circle,
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: backgroundColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isDisabled ? iconColor.withValues(alpha: 0.5) : iconColor,
          size: size * 0.45,
        ),
      ),
    );
  }
}
