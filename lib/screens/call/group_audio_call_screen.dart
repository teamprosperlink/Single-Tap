import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/config/app_colors.dart';
import '../../services/notification_service.dart';
import '../../services/other services/group_voice_call_service.dart';
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

class _GroupAudioCallScreenState extends State<GroupAudioCallScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupVoiceCallService _groupVoiceCallService = GroupVoiceCallService();

  Timer? _callTimer;
  int _callDuration = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isEndingCall = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Track participant info: participantId -> {name, photoUrl, isActive}
  final Map<String, Map<String, dynamic>> _participantInfo = {};
  StreamSubscription? _participantsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('  GroupAudioCallScreen: initState - callId=${widget.callId}');

    // Initialize pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // CRITICAL FIX: Deduplicate participants by userId before storing
    // This prevents duplicate participant cards in the UI
    final seenUserIds = <String>{};
    int duplicateCount = 0;

    for (var participant in widget.participants) {
      final userId = participant['userId'] as String;

      if (!seenUserIds.contains(userId)) {
        // First time seeing this userId - add to map
        seenUserIds.add(userId);
        _participantInfo[userId] = {
          'name': participant['name'] ?? 'Unknown',
          'photoUrl': participant['photoUrl'],
          'isActive': userId == widget.userId, // Current user is active
        };
      } else {
        // Duplicate userId found - skip it
        duplicateCount++;
        debugPrint(
          '⚠️ Skipping duplicate participant: $userId (${participant['name']})',
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
            }
          };

      _groupVoiceCallService.onParticipantLeft = (participantId) {
        debugPrint('  Participant left WebRTC: $participantId');
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

  @override
  void dispose() {
    _callTimer?.cancel();
    _participantsSubscription?.cancel();
    _pulseController.dispose();

    // Clean up WebRTC
    _groupVoiceCallService.leaveCall();

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
                  setState(() {
                    _participantInfo[userId] = {
                      'name': userData?['name'] ?? 'Unknown',
                      'photoUrl': userData?['photoUrl'],
                      'isActive': data['isActive'] == true,
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
              // Existing participant - just update active status
              if (mounted) {
                setState(() {
                  _participantInfo[userId]!['isActive'] =
                      data['isActive'] == true;
                });
              }
            }
          }

          // Start timer only when at least one other person (not current user) becomes active
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

  Future<void> _updateCallStatus(String status) async {
    try {
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'status': status,
        if (status == 'ended') 'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('  Error updating call status: $e');
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
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      // Leave WebRTC call first
      await _groupVoiceCallService.leaveCall();

      await _updateParticipantStatus(false);
      await _updateCallStatus('ended');

      // Update system message with call duration and participant count
      final callDoc = await _firestore
          .collection('group_calls')
          .doc(widget.callId)
          .get();
      if (callDoc.exists) {
        final callData = callDoc.data();
        final systemMessageId = callData?['systemMessageId'] as String?;
        final groupId = callData?['groupId'] as String?;

        // Count participants who joined (were active at some point)
        final activeParticipantCount = _participantInfo.values
            .where(
              (info) => info['isActive'] == true || info['wasActive'] == true,
            )
            .length;

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
        }
      }
    } catch (e) {
      debugPrint('  Error ending call: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
                // Header
                _buildHeader(),

                const SizedBox(height: 40),

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

                const Spacer(),

                // Participants grid
                _buildParticipantsGrid(activeParticipants),

                const Spacer(),

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
      child: Row(
        children: [
          const Icon(Icons.group_rounded, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_participantInfo.length} ${_participantInfo.length == 1 ? 'participant' : 'participants'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Add participant button
          Container(
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
        ],
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

      // Get current call participants
      final currentParticipantIds = _participantInfo.keys.toSet();

      // Filter out members already in the call
      final availableMemberIds = allMemberIds
          .where((id) => !currentParticipantIds.contains(id))
          .toList();

      if (availableMemberIds.isEmpty) {
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

      // Fetch member details
      final memberDetails = <Map<String, dynamic>>[];
      for (final memberId in availableMemberIds) {
        final userDoc = await _firestore
            .collection('users')
            .doc(memberId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          memberDetails.add({
            'userId': memberId,
            'name': userData['name'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
          });
        }
      }

      if (!mounted) return;

      // Show bottom sheet with available members
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Add Participants',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Member list
              Expanded(
                child: ListView.builder(
                  itemCount: memberDetails.length,
                  itemBuilder: (context, index) {
                    final member = memberDetails[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: member['photoUrl'] != null
                            ? CachedNetworkImageProvider(member['photoUrl'])
                            : null,
                        backgroundColor: AppColors.iosBlue.withValues(
                          alpha: 0.2,
                        ),
                        child: member['photoUrl'] == null
                            ? Text(
                                (member['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        member['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
    try {
      // Add participant to call document
      await _firestore.collection('group_calls').doc(widget.callId).update({
        'participants': FieldValue.arrayUnion([member['userId']]),
      });

      // Send notification to the member
      await NotificationService().sendNotificationToUser(
        userId: member['userId'],
        title: 'Incoming Group Audio Call',
        body: '${widget.userName} added you to ${widget.groupName}',
        type: 'group_audio_call',
        data: {
          'callId': widget.callId,
          'groupId': widget.groupId,
          'groupName': widget.groupName,
          'callerId': widget.userId,
          'isVideo': false,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${member['name']} to the call'),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding participant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add ${member['name']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildParticipantsGrid(List<Map<String, dynamic>> activeParticipants) {
    // Show ONLY active/connected participants (excluding current user)
    final connectedParticipants = _participantInfo.entries
        .where(
          (entry) =>
              entry.key != widget.userId && // Exclude current user
              entry.value['isActive'] == true,
        ) // Only show connected users
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for others to join...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: GridView.builder(
        key: ValueKey(connectedParticipants.length),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: connectedParticipants.length <= 4 ? 2 : 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: connectedParticipants.length,
        itemBuilder: (context, index) {
          final participant = connectedParticipants[index];

          return _buildParticipantCard(
            participant['name'] ?? 'Unknown',
            participant['photoUrl'],
            false, // Never current user (already filtered out)
            true, // Always active (already filtered)
          );
        },
      ),
    );
  }

  Widget _buildParticipantCard(
    String name,
    String? photoUrl,
    bool isCurrentUser,
    bool isActive,
  ) {
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isCurrentUser
              ? [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)]
              : [const Color(0xFF2F2F2F), const Color(0xFF1F1F1F)],
        ),
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile picture with pulse/waveform animation
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF25D366) // WhatsApp green
                      : Colors.white.withValues(alpha: 0.25),
                  width: 3,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
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
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            isCurrentUser ? 'You' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 4),

          // Status indicator
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
        ],
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
            onTap: _endCall,
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
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}
