import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

// Screens used in navigation
import 'home_screen.dart';
import 'live_connect_tab_screen.dart';
import 'feed_screen.dart';
import 'conversations_screen.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/business_main_screen.dart';

// Call screens - Now using CallKit instead of IncomingCallScreen widget
// Video call disabled
// import '../call/incoming_video_call_screen.dart';

// services
import '../../services/location services/location_service.dart';
import '../../services/notification_service.dart';
import '../../models/message_model.dart';

// widgets
import '../../widgets/app_drawer.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  final String? loginAccountType; // Account type from login screen

  // Static GlobalKey for Scaffold to open drawer from external screens
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  const MainNavigationScreen({
    super.key,
    this.initialIndex,
    this.loginAccountType,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;

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

    // Initialize TabController with 4 tabs
    _tabController = TabController(length: 4, vsync: this);

    // Set initial index based on login account type or initialIndex
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
      _tabController.index = _convertToTabIndex(_currentIndex);
      _saveScreenIndex(_currentIndex);
    } else if (widget.loginAccountType != null) {
      // Set initial screen based on account type from login
      if (widget.loginAccountType == 'Business Account') {
        _currentIndex = 6; // Business dashboard
      } else {
        _currentIndex = 0; // Home screen for Personal
        _tabController.index = _convertToTabIndex(0);
      }
      _saveScreenIndex(_currentIndex);
    } else {
      // Always start at home screen on refresh
      _currentIndex = 0;
      _tabController.index = _convertToTabIndex(0);
    }

    // Listen to tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final newIndex = _convertFromTabIndex(_tabController.index);
      if (newIndex != _currentIndex) {
        HapticFeedback.mediumImpact();
        setState(() => _currentIndex = newIndex);
        _saveScreenIndex(newIndex);
      }
    });

    // Initialize listeners with error handling
    _safeInit();
  }

  // Convert main index to tab index (0-3)
  int _convertToTabIndex(int mainIndex) {
    switch (mainIndex) {
      case 4:
        return 0; // Nearby (Feed)
      case 0:
        return 1; // Home
      case 1:
        return 2; // Chat
      case 2:
        return 3; // Networking
      default:
        return 1;
    }
  }

  // Convert tab index (0-3) to main index
  int _convertFromTabIndex(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 4; // Nearby (Feed)
      case 1:
        return 0; // Home
      case 2:
        return 1; // Chat
      case 3:
        return 2; // Networking
      default:
        return 0;
    }
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

    // Start listening for group audio calls (Firestore real-time listener)
    try {
      final notificationService = NotificationService();
      debugPrint('========================================');
      debugPrint('  INITIALIZING GROUP CALL LISTENER');
      debugPrint('========================================');
      notificationService.startListeningForGroupCalls();
      debugPrint('    Group call listener initialized in MainNavigationScreen');

      // Run diagnostic test to verify document access
      debugPrint('  Running diagnostic test...');
      notificationService.testGroupCallDocumentAccess().then((_) {
        debugPrint('  Diagnostic test completed');
      });
    } catch (e) {
      debugPrint('   ERROR starting group call listener: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
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
    _tabController.dispose();
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

    debugPrint('   Setting up call listener for receiverId: $currentUserId');

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
                final receiverId = data['receiverId'] as String? ?? '';

                debugPrint(
                  ' Call found: ID=$callId, Caller=$callerId, Receiver=$receiverId, Status=$status, CurrentUser=$currentUserId',
                );

                // Skip if already handled
                if (_handledCallIds.contains(callId)) {
                  debugPrint('    Skipping - already handled');
                  continue;
                }

                // Skip caller's own calls
                if (callerId == currentUserId) {
                  debugPrint('    Skipping - user is caller, not receiver');
                  _handledCallIds.add(callId);
                  continue;
                }

                // CRITICAL: Verify this call is actually for current user
                if (receiverId != currentUserId) {
                  debugPrint(
                    '   ERROR: Call receiverId ($receiverId) != currentUserId ($currentUserId) - QUERY ISSUE!',
                  );
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

                  // If call is more than 39 seconds old, mark as missed (timeout)
                  // This matches the caller's timeout duration
                  if (callAge > 39) {
                    debugPrint(
                      '  First snapshot: Call $callId is $callAge seconds old (timeout), marking as missed',
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
                    // Call is within timeout period (39 seconds) AND still in 'calling' status
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
              final callerId = data['callerId'] as String? ?? '';
              final receiverId = data['receiverId'] as String? ?? '';

              debugPrint(
                ' NEW call detected: ID=$callId, Caller=$callerId, Receiver=$receiverId, Status=$status, CurrentUser=$currentUserId',
              );

              // Skip if we've already handled this call
              if (_handledCallIds.contains(callId)) {
                debugPrint('    Skipping - already handled');
                continue;
              }

              // Skip if current user is the caller (not the receiver)
              if (callerId == currentUserId) {
                debugPrint('    Skipping - user is caller, not receiver');
                _handledCallIds.add(callId);
                continue;
              }

              // Verify receiver ID matches current user
              if (receiverId != currentUserId) {
                debugPrint(
                  '   ERROR: Call receiverId ($receiverId) != currentUserId ($currentUserId) - QUERY ISSUE!',
                );
                _handledCallIds.add(callId);
                continue;
              }

              debugPrint(
                '   Valid incoming call for current user - showing call screen',
              );

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

    // Get call type (audio/video) from Firestore
    String callType = 'audio'; // default
    try {
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      callType = callDoc.data()?['type'] ?? 'audio';
      debugPrint('  Call type: $callType');
    } catch (e) {
      debugPrint('  Error getting call type: $e');
    }

    // CRITICAL FIX: Use CallKit for WhatsApp-style full-screen incoming call UI
    // This replaces the old IncomingCallScreen widget approach
    // CallKit provides native full-screen UI even when app is in foreground

    debugPrint(' Showing CallKit full-screen UI for incoming call');

    // Video calling disabled - auto-reject video calls
    if (callType == 'video') {
      debugPrint('  Video call rejected (feature disabled): $callId');
      try {
        await _firestore.collection('calls').doc(callId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error rejecting video call: $e');
      }
      _isShowingIncomingCall = false;
      return;
    }

    // Show CallKit full-screen incoming call UI (like WhatsApp)
    try {
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName.isNotEmpty ? callerName : 'Unknown',
        appName: 'Supper',
        avatar: callerPhoto,
        handle: 'Voice Call',
        type: 0, // Audio call
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Missed Call',
          callbackText: 'Call back',
        ),
        duration: 60000, // 60 seconds timeout
        extra: <String, dynamic>{
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callerPhoto': callerPhoto,
        },
        headers: <String, dynamic>{},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0f0f23',
          backgroundUrl: '',
          actionColor: '#4CAF50',
          textColor: '#FFFFFF',
          incomingCallNotificationChannelName: 'Incoming Calls',
          missedCallNotificationChannelName: 'Missed Calls',
          isShowCallID: false,
          isShowFullLockedScreen: true,
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: false,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
      debugPrint('  CallKit UI shown successfully');

      // Update call status to 'ringing' so caller sees "Ringing..."
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
      debugPrint('  Call status updated to ringing');
    } catch (e) {
      debugPrint('  Error showing CallKit UI: $e');
      _isShowingIncomingCall = false;
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
      if (existingMessage.exists) {
        debugPrint(
          '  Missed call message already exists for callId=$callId, skipping',
        );
        return;
      }

      // Get call type from Firestore to determine correct message text
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callType = callDoc.data()?['type'] as String? ?? 'audio';
      final isVideo = callType == 'video';

      final now = DateTime.now();

      // Create missed call message - senderId is CALLER so receiver sees it as incoming
      await messageRef.set({
        'id': messageId,
        'senderId': callerId,
        'receiverId': currentUserId,
        'chatId': conversationId,
        'text': isVideo ? 'Missed video call' : 'Missed voice call',
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
        .limit(50) // Limit to reduce Firebase reads
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            try {
              int total = 0;
              for (var doc in snap.docs) {
                total += ((doc["unreadCount"]?[user.uid] ?? 0) as num).toInt();
              }
              // Unread count updated
              setState(() {});
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
        return HomeScreen(key: HomeScreen.globalKey);
      case 1:
        return const ConversationsScreen(); // Chat/Messages screen
      case 2:
        return const LiveConnectTabScreen(
          activateNetworkingFilter: true,
        ); // Networking with professional filters
      case 4:
        return FeedScreen(
          // Nearby - Feed Screen
          onBack: () {
            setState(() => _currentIndex = 0);
          },
        );
      case 5:
        return const ProfessionalDashboardScreen();
      case 6:
        return const BusinessMainScreen();
      default:
        return HomeScreen(key: HomeScreen.globalKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // For Business and Professional screens, show without TabBar
    if (_currentIndex == 6 || _currentIndex == 5) {
      return Scaffold(body: _buildScreen());
    }

    // For Chat, Networking, and Nearby - show them fullscreen without the main TabBar
    // But still keep the bottom navigation for easy switching between screens

    // Create bottom navigation bar widget with gradient like AppBar
    Widget buildBottomNavBar() {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
              border: const Border(
                top: BorderSide(color: Colors.white, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.explore,
                      label: 'Nearby',
                      index: 4,
                      isActive: _currentIndex == 4,
                    ),
                    _buildNavItem(
                      icon: Icons.home,
                      label: 'Home',
                      index: 0,
                      isActive: _currentIndex == 0,
                    ),
                    _buildNavItem(
                      icon: Icons.chat_bubble,
                      label: 'Chat',
                      index: 1,
                      isActive: _currentIndex == 1,
                    ),
                    _buildNavItem(
                      icon: Icons.business_center,
                      label: 'Networking',
                      index: 2,
                      isActive: _currentIndex == 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_currentIndex == 1) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: const ConversationsScreen(),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }
    if (_currentIndex == 2) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: const LiveConnectTabScreen(activateNetworkingFilter: true),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }
    if (_currentIndex == 4) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: FeedScreen(
          onBack: () {
            setState(() {
              _currentIndex = 0;
              _tabController.index = 0;
            });
          },
        ),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }

    // For Home screen - show with icon-based bottom navigation (same as Messages screen)
    return Scaffold(
      key: MainNavigationScreen.scaffoldKey,
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      endDrawer: AppDrawer(
        key: AppDrawer.globalKey,
        onNewChat: () async {
          // Reset for new chat (conversations are auto-saved)
          await HomeScreen.globalKey.currentState?.saveConversationAndReset();
          // Navigate to home screen
          setState(() => _currentIndex = 0);
        },
        onLoadChat: (chatId) async {
          // Load conversation from history (ChatGPT style)
          await HomeScreen.globalKey.currentState?.loadConversation(chatId);
          // Navigate to home screen
          setState(() => _currentIndex = 0);
        },
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
            if (index <= 3) {
              _tabController.index = _convertToTabIndex(index);
            }
          });
          _saveScreenIndex(index);
        },
      ),
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 56,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Center(
            child: Text(
              'Single Tap',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        leadingWidth: 100,
        title: const SizedBox.shrink(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Refresh chat list when drawer opens (not on every message)
                AppDrawer.globalKey.currentState?.refreshChatHistory();
                MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
            border: const Border(
              bottom: BorderSide(color: Colors.white, width: 0.5),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          HomeScreen(key: HomeScreen.globalKey),

          // Swipe gesture detector for Feed
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
      bottomNavigationBar: buildBottomNavBar(),
    );
  }

  // Build navigation item for bottom nav
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _currentIndex = index;
            if (index <= 3) {
              _tabController.index = _convertToTabIndex(index);
            }
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
