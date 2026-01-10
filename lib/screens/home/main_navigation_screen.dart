import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

// Replace these with your actual screens
import 'home_screen.dart';
import 'conversations_screen.dart';
import 'live_connect_tab_screen.dart';
import 'profile_with_history_screen.dart';
import 'feed_screen.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/business_main_screen.dart';

// Call screens
import '../chat/incoming_call_screen.dart';

// services
import '../../services/location services/location_service.dart';
import '../../services/notification_service.dart';
import '../../models/message_model.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  final String? loginAccountType; // Account type from login screen

  const MainNavigationScreen({
    super.key,
    this.initialIndex,
    this.loginAccountType,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadMessageCount = 0;

  // Stream subscription for cleanup
  StreamSubscription<QuerySnapshot>? _unreadSubscription;
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;
  bool _isShowingIncomingCall = false;
  final Set<String> _handledCallIds = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _location = LocationService();

  static const String _screenIndexKey = 'last_screen_index';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set initial index based on login account type or initialIndex
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
      _saveScreenIndex(_currentIndex);
    } else if (widget.loginAccountType != null) {
      // Set initial screen based on account type from login
      if (widget.loginAccountType == 'Business Account') {
        _currentIndex = 6; // Business dashboard
      } else {
        _currentIndex = 0; // Home screen for Personal
      }
      _saveScreenIndex(_currentIndex);
    } else {
      // Load saved screen index (instant, no Firebase needed)
      _loadSavedScreenIndex();
    }

    // Initialize listeners with error handling
    _safeInit();
  }

  void _safeInit() {
    try {
      _listenUnread();
    } catch (e) {
      debugPrint('Error in _listenUnread: $e');
    }

    try {
      _listenForIncomingCalls();
    } catch (e) {
      debugPrint('Error in _listenForIncomingCalls: $e');
    }

    // Run these async operations without blocking
    _checkAndMarkMissedCalls().catchError((e) {
      debugPrint('Error in _checkAndMarkMissedCalls: $e');
    });

    try {
      _updateStatus(true);
    } catch (e) {
      debugPrint('Error in _updateStatus: $e');
    }

    try {
      _checkLocation();
    } catch (e) {
      debugPrint('Error in _checkLocation: $e');
    }
  }

  // Save screen index locally for instant restore
  Future<void> _saveScreenIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_screenIndexKey, index);
  }

  // Load saved screen index instantly
  Future<void> _loadSavedScreenIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_screenIndexKey);
    if (savedIndex != null && mounted) {
      setState(() {
        _currentIndex = savedIndex;
      });
    }
  }

  // Check for old calls that were never answered and mark them as missed
  Future<void> _checkAndMarkMissedCalls() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get calls where this user is the receiver and status is still calling/ringing
      // Use simple query to avoid index requirements
      final oldCalls = await _firestore
          .collection('calls')
          .where('receiverId', isEqualTo: user.uid)
          .get();

      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(seconds: 60));

      for (var doc in oldCalls.docs) {
        final data = doc.data();
        final status = data['status'] as String?;

        // Only process calls that are still in calling/ringing state
        if (status != 'calling' && status != 'ringing') continue;

        // Use timestamp or createdAt field
        final timestamp = data['timestamp'] ?? data['createdAt'];
        DateTime? callTime;

        if (timestamp is Timestamp) {
          callTime = timestamp.toDate();
        } else if (timestamp is String) {
          callTime = DateTime.tryParse(timestamp);
        }

        // If call is older than 60 seconds, mark as missed
        if (callTime != null && callTime.isBefore(cutoffTime)) {
          await _firestore.collection('calls').doc(doc.id).update({
            'status': 'missed',
            'missedAt': FieldValue.serverTimestamp(),
          });

          // Show missed call notification
          final callerName = data['callerName'] as String? ?? 'Unknown';
          _showMissedCallNotification(callerName);
        }
      }
    } catch (e) {
      debugPrint('Error checking missed calls: $e');
    }
  }

  void _showMissedCallNotification(String callerName) {
    // Snackbar removed - missed call is shown in chat instead
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('  _listenForIncomingCalls: No user logged in');
      return;
    }

    _incomingCallSubscription?.cancel();

    final currentUserId = user.uid;
    debugPrint(
      '  _listenForIncomingCalls: Listening for calls to $currentUserId',
    );

    // Track first snapshot to handle existing calls differently
    bool isFirstSnapshot = true;

    // Query with orderBy - requires Firestore composite index on calls(receiverId, createdAt)
    // If index doesn't exist, we'll catch the error and use a simpler query
    _startCallListener(currentUserId, isFirstSnapshot, useOrderBy: true);
  }

  void _startCallListener(
    String currentUserId,
    bool isFirstSnapshot, {
    required bool useOrderBy,
  }) {
    _incomingCallSubscription?.cancel();

    Query<Map<String, dynamic>> query = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId);

    if (useOrderBy) {
      query = query.orderBy('createdAt', descending: true);
    }

    _incomingCallSubscription = query
        .limit(5)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '  Call snapshot received: ${snapshot.docs.length} docs, ${snapshot.docChanges.length} changes, isFirst=$isFirstSnapshot',
            );
            if (!mounted || _isShowingIncomingCall) {
              debugPrint(
                '  Skipping: mounted=$mounted, _isShowingIncomingCall=$_isShowingIncomingCall',
              );
              return;
            }

            // Get current time for checking call freshness
            final now = DateTime.now();

            // On first snapshot, check ALL existing calls
            // IMPORTANT: Only show calls that are STILL in 'calling' status AND very fresh
            // If caller has already cut the call (status != 'calling'), mark as missed
            if (isFirstSnapshot) {
              isFirstSnapshot = false;
              debugPrint('  First snapshot - checking existing calls');

              for (var doc in snapshot.docs) {
                final data = doc.data();
                final callId = doc.id;
                final status = data['status'] as String? ?? '';
                final callerId = data['callerId'] as String? ?? '';

                // Skip if already handled
                if (_handledCallIds.contains(callId)) continue;

                // Skip caller's own calls
                if (callerId == currentUserId) {
                  _handledCallIds.add(callId);
                  continue;
                }

                // CRITICAL: If call is NOT in 'calling' status, it means caller already cut
                // In this case, we should NOT show call screen, just mark as handled
                if (status != 'calling') {
                  debugPrint(
                    '  First snapshot: Call $callId status is "$status" (not calling), skipping',
                  );
                  _handledCallIds.add(callId);

                  // If status is 'ended' or 'missed' (caller cut before receiver answered), show missed notification
                  if (status == 'ended' || status == 'missed') {
                    debugPrint(
                      '  First snapshot: Call $callId was $status by caller, showing missed notification',
                    );

                    // Only update to missed if it was 'ended'
                    if (status == 'ended') {
                      _firestore.collection('calls').doc(callId).update({
                        'status': 'missed',
                        'missedAt': FieldValue.serverTimestamp(),
                      });
                    }

                    // Check if missed call message already exists before sending
                    _sendMissedCallToChat(
                      callId: callId,
                      callerId: callerId,
                      callerName: data['callerName'] as String? ?? 'Unknown',
                    );
                    _showMissedCallNotification(
                      data['callerName'] as String? ?? 'Unknown',
                    );
                  }
                  continue;
                }

                // Call is in 'calling' status - check how old it is
                final timestamp = data['timestamp'] ?? data['createdAt'];
                DateTime? callTime;
                if (timestamp is Timestamp) {
                  callTime = timestamp.toDate();
                }

                if (callTime != null) {
                  final callAge = now.difference(callTime).inSeconds;

                  // If call is more than 5 seconds old, mark as missed
                  // (caller probably already gave up or app was closed for too long)
                  if (callAge > 5) {
                    debugPrint(
                      '  First snapshot: Call $callId is $callAge seconds old, marking as missed',
                    );
                    _handledCallIds.add(callId);

                    _firestore.collection('calls').doc(callId).update({
                      'status': 'missed',
                      'missedAt': FieldValue.serverTimestamp(),
                    });

                    _sendMissedCallToChat(
                      callId: callId,
                      callerId: callerId,
                      callerName: data['callerName'] as String? ?? 'Unknown',
                    );

                    _showMissedCallNotification(
                      data['callerName'] as String? ?? 'Unknown',
                    );
                  } else {
                    // Call is very recent (within 5 seconds) AND still in 'calling' status
                    // This means caller is still waiting - show the call
                    debugPrint(
                      '  First snapshot: Call $callId is only $callAge seconds old and still calling, showing incoming call',
                    );
                    _handledCallIds.add(callId);

                    final callerName =
                        data['callerName'] as String? ?? 'Unknown';
                    final callerPhoto = data['callerPhoto'] as String?;

                    _showIncomingCall(
                      callId: callId,
                      callerName: callerName,
                      callerPhoto: callerPhoto,
                      callerId: callerId,
                    );
                    return; // Only show one call
                  }
                } else {
                  // No timestamp, mark as missed to be safe
                  debugPrint(
                    '  First snapshot: Call $callId has no timestamp, marking as missed',
                  );
                  _handledCallIds.add(callId);
                  _firestore.collection('calls').doc(callId).update({
                    'status': 'missed',
                    'missedAt': FieldValue.serverTimestamp(),
                  });
                  _sendMissedCallToChat(
                    callId: callId,
                    callerId: callerId,
                    callerName: data['callerName'] as String? ?? 'Unknown',
                  );
                  _showMissedCallNotification(
                    data['callerName'] as String? ?? 'Unknown',
                  );
                }
              }
              return;
            }

            // After first snapshot, only process NEW calls (docChanges with type=added)
            for (var change in snapshot.docChanges) {
              // Only process newly added documents
              if (change.type != DocumentChangeType.added) continue;

              final doc = change.doc;
              final data = doc.data();
              if (data == null) continue;

              final callId = doc.id;
              final status = data['status'] as String? ?? '';

              // Skip if we've already handled this call
              if (_handledCallIds.contains(callId)) continue;

              final callerId = data['callerId'] as String? ?? '';
              final receiverId = data['receiverId'] as String? ?? '';

              // Skip if current user is the caller (not the receiver)
              if (callerId == currentUserId) {
                _handledCallIds.add(callId);
                continue;
              }

              // Verify receiver ID matches current user
              if (receiverId != currentUserId) {
                _handledCallIds.add(callId);
                continue;
              }

              // Check if call is still active (status = 'calling')
              if (status != 'calling') {
                debugPrint('  Call $callId status is $status, not calling');
                _handledCallIds.add(callId);
                continue;
              }

              // Get call timestamp
              final timestamp = data['timestamp'] ?? data['createdAt'];
              DateTime? callTime;
              if (timestamp is Timestamp) {
                callTime = timestamp.toDate();
              }

              // Check if call is too old (more than 60 seconds) - mark as missed
              final cutoffTime = now.subtract(const Duration(seconds: 60));
              if (callTime != null && callTime.isBefore(cutoffTime)) {
                debugPrint('  Call $callId too old, marking as missed');
                _handledCallIds.add(callId);

                _firestore.collection('calls').doc(callId).update({
                  'status': 'missed',
                  'missedAt': FieldValue.serverTimestamp(),
                });

                _sendMissedCallToChat(
                  callId: callId,
                  callerId: callerId,
                  callerName: data['callerName'] as String? ?? 'Unknown',
                );

                _showMissedCallNotification(
                  data['callerName'] as String? ?? 'Unknown',
                );
                continue;
              }

              // This is a fresh, active call - show incoming call screen
              _handledCallIds.add(callId);

              final callerName = data['callerName'] as String? ?? 'Unknown';
              final callerPhoto = data['callerPhoto'] as String?;

              debugPrint('   Showing incoming call from $callerName');
              _showIncomingCall(
                callId: callId,
                callerName: callerName,
                callerPhoto: callerPhoto,
                callerId: callerId,
              );
              break;
            }
          },
          onError: (error) {
            debugPrint('   Error listening to calls: $error');

            // If error is due to missing index, retry without orderBy
            if (useOrderBy && error.toString().contains('index')) {
              debugPrint('  Retrying without orderBy due to missing index');
              _startCallListener(currentUserId, true, useOrderBy: false);
            }
          },
        );
  }

  void _showIncomingCall({
    required String callId,
    required String callerName,
    String? callerPhoto,
    required String callerId,
  }) async {
    if (_isShowingIncomingCall) return;

    _isShowingIncomingCall = true;
    HapticFeedback.heavyImpact();

    debugPrint(
      '  _showIncomingCall: Showing IncomingCallScreen for callId=$callId',
    );

    // IMPORTANT: End any existing CallKit UI to prevent conflicts
    // This prevents CallKit timeout from marking call as missed
    try {
      await FlutterCallkitIncoming.endAllCalls();
      debugPrint('  Ended all CallKit calls to prevent conflict');
    } catch (e) {
      debugPrint('  Error ending CallKit calls: $e');
    }

    // Update call status to 'ringing' so caller sees "Ringing..." (like WhatsApp)
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
      debugPrint('  Call status updated to ringing');
    } catch (e) {
      debugPrint('  Error updating call status to ringing: $e');
    }

    // Show our custom IncomingCallScreen (WhatsApp style) directly
    // This works better than CallKit when app is in foreground
    if (mounted && context.mounted) {
      try {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => IncomingCallScreen(
                  callId: callId,
                  callerName: callerName.isNotEmpty ? callerName : 'Unknown',
                  callerPhoto: callerPhoto,
                  callerId: callerId,
                ),
              ),
            )
            .then((_) {
              // Reset flag when screen is closed
              _isShowingIncomingCall = false;
            })
            .catchError((e) {
              debugPrint('  Navigation error: $e');
              _isShowingIncomingCall = false;
            });
      } catch (e) {
        debugPrint('  Error showing IncomingCallScreen: $e');
        _isShowingIncomingCall = false;
      }
    } else {
      _isShowingIncomingCall = false;
      debugPrint('  Not mounted, cannot show IncomingCallScreen');
    }
  }

  /// Send missed call message to chat conversation
  Future<void> _sendMissedCallToChat({
    required String callId,
    required String callerId,
    required String callerName,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Create conversation ID (sorted participant IDs)
      final participants = [currentUserId, callerId]..sort();
      final conversationId = participants.join('_');

      // Check if conversation exists, create if not
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      // Use deterministic message ID based on call ID to prevent duplicates
      final messageId = 'call_$callId';
      final messageRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId);

      // Check if message already exists
      final existingMessage = await messageRef.get();
      if (existingMessage.exists) return;

      final now = DateTime.now();

      // Create missed call message - senderId is CALLER so receiver sees it as incoming
      await messageRef.set({
        'id': messageId,
        'senderId': callerId,
        'receiverId': currentUserId,
        'chatId': conversationId,
        'text': 'Missed voice call',
        'type': MessageType.missedCall.index,
        'status': MessageStatus.delivered.index,
        'timestamp': Timestamp.fromDate(now),
        'isEdited': false,
        'read': false,
        'isRead': false,
        'metadata': {
          'callId': callId,
          'duration': 0,
          'isOutgoing': false,
          'isMissed': true,
        },
      });

      // Update conversation last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': '  Missed call',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': callerId,
      });
    } catch (e) {
      debugPrint('Error sending missed call to chat: $e');
    }
  }

  void _checkLocation() async {
    try {
      await _location.checkAndRefreshStaleLocation();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_auth.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }
  }

  void _updateStatus(bool online) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      _firestore
          .collection("users")
          .doc(uid)
          .update({
            "isOnline": online,
            "lastSeen": FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            debugPrint('Error updating status: $e');
          });
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _listenUnread() {
    final user = _auth.currentUser;
    if (user == null) return;

    _unreadSubscription?.cancel();
    _unreadSubscription = _firestore
        .collection("conversations")
        .where("participants", arrayContains: user.uid)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            try {
              int total = 0;
              for (var doc in snap.docs) {
                total += ((doc["unreadCount"]?[user.uid] ?? 0) as num).toInt();
              }
              setState(() => _unreadMessageCount = total);
              NotificationService().updateBadgeCount(total);
            } catch (e) {
              debugPrint('Error processing unread count: $e');
            }
          },
          onError: (error) {
            debugPrint('Unread listener error: $error');
          },
        );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ConversationsScreen();
      case 2:
        return const LiveConnectTabScreen();
      case 3:
        return const ProfileWithHistoryScreen();
      case 5:
        return const ProfessionalDashboardScreen();
      case 6:
        return const BusinessMainScreen();
      case 7:
        return FeedScreen(
          onBack: () {
            setState(() => _currentIndex = 0);
          },
        );
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _buildScreen(),

          // Bottom Navigation Bar (hide on Feed, Business, and Professional screens)
          if (_currentIndex != 7 && _currentIndex != 6 && _currentIndex != 5)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ModernBottomNavBar(
                currentIndex: _currentIndex,
                unreadCount: _unreadMessageCount,
                onTap: (index) {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentIndex = index);
                  _saveScreenIndex(index);
                },
              ),
            ),

          // Swipe gesture detector for Feed
          if (_currentIndex == 0)
            Positioned(
              left: 0,
              top: 0,
              height: size.height - 100,
              width: 100,
              child: _SwipeDetector(
                onSwipeRight: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentIndex = 7);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Modern Bottom Navigation Bar - 4 tabs with proper styling
class _ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int unreadCount;
  final Function(int) onTap;

  const _ModernBottomNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  isSelected: currentIndex == 1,
                  badge: unreadCount > 0 ? unreadCount : null,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: 'Networking',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Individual navigation item - icon with label below
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 24,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
                // Badge
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badge! > 99 ? '99+' : badge.toString(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Label always visible
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Swipe Detector for Feed access
class _SwipeDetector extends StatefulWidget {
  final VoidCallback? onSwipeRight;

  const _SwipeDetector({this.onSwipeRight});

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  double _startX = 0;
  bool _hasTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _startX = event.position.dx;
        _hasTriggered = false;
      },
      onPointerMove: (event) {
        if (_hasTriggered) return;

        final deltaX = event.position.dx - _startX;

        if (widget.onSwipeRight != null && deltaX > 30) {
          _hasTriggered = true;
          widget.onSwipeRight!();
        }
      },
      onPointerUp: (_) {
        _hasTriggered = false;
      },
      child: Container(color: Colors.transparent),
    );
  }
}
