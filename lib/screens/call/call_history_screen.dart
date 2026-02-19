import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../res/config/app_colors.dart';
import '../../models/user_profile.dart';
import '../../widgets/safe_circle_avatar.dart';
import 'voice_call_screen.dart';

class CallHistoryScreen extends StatefulWidget {
  final bool startInSelectionMode;
  final String? initialSelectedCallId;

  const CallHistoryScreen({
    super.key,
    this.startInSelectionMode = false,
    this.initialSelectedCallId,
  });

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  late bool _isSelectionMode;
  final Set<String> _selectedCallIds = {};

  @override
  void initState() {
    super.initState();
    _isSelectionMode = widget.startInSelectionMode;
    if (widget.initialSelectedCallId != null) {
      _selectedCallIds.add(widget.initialSelectedCallId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call History')),
        body: const Center(child: Text('Please sign in to view call history')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.splashDark3,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isSelectionMode
              ? '${_selectedCallIds.length} selected'
              : 'Call History',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_isSelectionMode) ...[
            // Select All button
            TextButton(
              onPressed: _selectAll,
              child: Text(
                'Select All',
                style: TextStyle(color: Colors.blue.shade300),
              ),
            ),
            // Delete selected button
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed:
                  _selectedCallIds.isEmpty ? null : _deleteSelectedCalls,
            ),
          ] else ...[
            // Enter selection mode button
            IconButton(
              icon: const Icon(Icons.checklist, color: Colors.white),
              onPressed: _enterSelectionMode,
              tooltip: 'Select calls',
            ),
          ],
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('calls')
            .where('participants', arrayContains: _currentUserId)
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading calls',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          }

          final calls = snapshot.data?.docs ?? [];

          if (calls.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.call_outlined,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No call history',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your calls will appear here',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: calls.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final callDoc = calls[index];
              final callData = callDoc.data() as Map<String, dynamic>;
              return _buildCallItem(callDoc.id, callData);
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildCallItem(String callId, Map<String, dynamic> callData) {
    final callerId = callData['callerId'] as String?;
    final receiverId = callData['receiverId'] as String?;
    final isOutgoing = callerId == _currentUserId;

    // Get other user's info
    final otherUserId = isOutgoing ? receiverId : callerId;
    final otherUserName = isOutgoing
        ? (callData['receiverName'] as String? ?? 'Unknown')
        : (callData['callerName'] as String? ?? 'Unknown');
    final otherUserPhoto = isOutgoing
        ? callData['receiverPhoto'] as String?
        : callData['callerPhoto'] as String?;

    final status = callData['status'] as String? ?? 'unknown';
    final timestamp = callData['createdAt'] as Timestamp?;
    final duration = callData['duration'] as int? ?? 0;

    final isSelected = _selectedCallIds.contains(callId);

    // Determine call status icon and color
    IconData statusIcon;
    Color statusColor;
    String statusText;

    if (status == 'missed') {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
      statusColor = Colors.red;
      statusText = isOutgoing ? 'No answer' : 'Missed';
    } else if (status == 'declined' || status == 'rejected') {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
      statusColor = Colors.orange;
      statusText = isOutgoing ? 'Declined' : 'Declined';
    } else if (status == 'ended' || status == 'connected') {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
      statusColor = Colors.green;
      final minutes = duration ~/ 60;
      final seconds = duration % 60;
      statusText = duration > 0
          ? '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
          : 'Connected';
    } else {
      statusIcon = Icons.call;
      statusColor = Colors.grey;
      statusText = status;
    }

    // Format timestamp
    String timeText = '';
    if (timestamp != null) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        timeText = DateFormat('h:mm a').format(date);
      } else if (diff.inDays == 1) {
        timeText = 'Yesterday';
      } else if (diff.inDays < 7) {
        timeText = DateFormat('EEEE').format(date);
      } else {
        timeText = DateFormat('MMM d').format(date);
      }
    }

    return Dismissible(
      key: Key(callId),
      direction: _isSelectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(1);
      },
      onDismissed: (direction) {
        _deleteCall(callId);
      },
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(callId);
          } else {
            _callUser(otherUserId, otherUserName, otherUserPhoto);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            HapticFeedback.mediumImpact();
            _enterSelectionMode();
            _toggleSelection(callId);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: isSelected ? 0.2 : 0.1),
                Colors.white.withValues(alpha: isSelected ? 0.12 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: isSelected ? 0.3 : 0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Selection checkbox (when in selection mode)
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(callId),
                  activeColor: Colors.blue,
                  checkColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 8),
              ],

              // Profile photo
              SafeCircleAvatar(
                photoUrl: otherUserPhoto,
                radius: 24,
                name: otherUserName,
              ),

              const SizedBox(width: 12),

              // Call info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Voice call',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time and call button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isSelectionMode)
                    GestureDetector(
                      onTap: () =>
                          _callUser(otherUserId, otherUserName, otherUserPhoto),
                      child: Icon(
                        Icons.call,
                        color: Colors.green.shade400,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedCallIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedCallIds.clear();
    });
  }

  void _toggleSelection(String callId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCallIds.contains(callId)) {
        _selectedCallIds.remove(callId);
        if (_selectedCallIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedCallIds.add(callId);
      }
    });
  }

  Future<void> _selectAll() async {
    final snapshot = await _firestore
        .collection('calls')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    setState(() {
      _selectedCallIds.clear();
      for (final doc in snapshot.docs) {
        _selectedCallIds.add(doc.id);
      }
    });
  }

  Future<bool> _showDeleteConfirmation(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'Delete Call',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              count == 1
                  ? 'Are you sure you want to delete this call from history?'
                  : 'Are you sure you want to delete $count calls from history?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
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
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedCalls() async {
    final confirmed = await _showDeleteConfirmation(_selectedCallIds.length);
    if (!confirmed) return;

    final batch = _firestore.batch();
    for (final callId in _selectedCallIds) {
      batch.delete(_firestore.collection('calls').doc(callId));
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedCallIds.length} calls deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete calls'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _callUser(
    String? userId,
    String userName,
    String? userPhoto,
  ) async {
    if (userId == null) return;

    // Create user profile for the call
    final now = DateTime.now();
    final userProfile = UserProfile(
      uid: userId,
      name: userName,
      email: '',
      profileImageUrl: userPhoto,
      createdAt: now,
      lastSeen: now,
    );

    // Create a new call document
    final callDoc = await _firestore.collection('calls').add({
      'callerId': _currentUserId,
      'receiverId': userId,
      'callerName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
      'callerPhoto': FirebaseAuth.instance.currentUser?.photoURL,
      'receiverName': userName,
      'receiverPhoto': userPhoto,
      'participants': [_currentUserId, userId],
      'status': 'calling',
      'type': 'audio',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    // Navigate to voice call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          callId: callDoc.id,
          otherUser: userProfile,
          isOutgoing: true,
        ),
      ),
    );
  }
}
