import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

// Screens used in navigation
import 'home_screen.dart';
import '../networking/live_connect_tab_screen.dart';
import '../networking/user_profile_detail_screen.dart';
import '../near by/near_by_screen.dart';
import '../chat/conversations_screen.dart';
import '../networking/pending_requests_screen.dart';
import '../networking/my_networking_profile_screen.dart';
import '../networking/create_networking_profile_screen.dart';
import '../networking/onboarding_networking_screen.dart';
import '../../models/extended_user_profile.dart';

// Professional & Business screens
import '../professional/professional_dashboard_screen.dart';
import '../business/business_main_screen.dart';

// Call screens - Now using CallKit instead of IncomingCallScreen widget
// Video call disabled
// import '../call/incoming_video_call_screen.dart';

// services
import '../../services/location_services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/connection_service.dart';
import '../../models/message_model.dart';

// widgets
import '../../widgets/common widgets/app_drawer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int? initialIndex;
  final String? loginAccountType; // Account type from login screen

  // Static GlobalKey for Scaffold to open drawer from external screens
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  const MainNavigationScreen({
    super.key,
    this.initialIndex,
    this.loginAccountType,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  late TabController _networkingTabController;
  int _networkingTabIndex = 0;
  int _networkingProfileCount = 0;
  StreamSubscription? _profileCountSub;

  // GlobalKeys to access LiveConnectTabScreen state for filter dialog
  final GlobalKey<LiveConnectTabScreenState> _discoverConnectKey = GlobalKey();
  final GlobalKey<LiveConnectTabScreenState> _smartConnectKey = GlobalKey();


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

    // Networking sub-tabs: Discover Connect, Smart Connect & Requests
    _networkingTabController = TabController(length: 3, vsync: this);
    _networkingTabController.addListener(() {
      if (!_networkingTabController.indexIsChanging) {
        setState(() {
          _networkingTabIndex = _networkingTabController.index;
        });

      }
    });

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
      case 0:
        return 0; // Home
      case 1:
        return 1; // Chat
      case 4:
        return 2; // Nearby
      case 2:
        return 3; // Networking
      default:
        return 0;
    }
  }

  // Convert tab index (0-3) to main index
  int _convertFromTabIndex(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Chat
      case 2:
        return 4; // Nearby
      case 3:
        return 2; // Networking
      default:
        return 0;
    }
  }

  void _listenNetworkingProfileCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _profileCountSub?.cancel();
    _profileCountSub = FirebaseFirestore.instance
        .collection('networking_profiles')
        .doc(uid)
        .collection('profiles')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _networkingProfileCount = snapshot.docs.length);
      }
    });
  }

  void _safeInit() {
    _listenNetworkingProfileCount();
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
    _networkingTabController.dispose();

    _unreadSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _profileCountSub?.cancel();
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

    // CRITICAL FIX: Use CallKit for SingleTap-style full-screen incoming call UI
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

    // Show CallKit full-screen incoming call UI (like SingleTap)
    try {
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName.isNotEmpty ? callerName : 'Unknown',
        appName: 'SingleTap',
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
      case 5:
        return const ProfessionalDashboardScreen();
      case 6:
        return const BusinessMainScreen();
      default:
        return const SizedBox.shrink();
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

    String formatTimeAgo(DateTime dateTime) {
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    }

    // Single request card widget — image LEFT, data + buttons RIGHT
    // Haversine distance calculation
    double calcDistance(double lat1, double lon1, double lat2, double lon2) {
      const earthRadius = 6371.0;
      final dLat = (lat2 - lat1) * pi / 180;
      final dLon = (lon2 - lon1) * pi / 180;
      final a =
          sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180) *
              cos(lat2 * pi / 180) *
              sin(dLon / 2) *
              sin(dLon / 2);
      return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
    }

    List<Color> getAvatarGradient(String name) {
      final hash = name.hashCode % 5;
      switch (hash) {
        case 0:
          return [const Color(0xFFFF6B9D), const Color(0xFFC7365F)];
        case 1:
          return [const Color(0xFF4A90E2), const Color(0xFF2E5BFF)];
        case 2:
          return [const Color(0xFFFF6B35), const Color(0xFFFF4E00)];
        case 3:
          return [const Color(0xFF9B59B6), const Color(0xFF6C3483)];
        default:
          return [const Color(0xFF00D67D), const Color(0xFF00A85E)];
      }
    }

    Widget buildNetworkMosaicCard({
      required String userName,
      required String? imageUrl,
      required double height,
      required VoidCallback onTap,
      VoidCallback? onMessage,
      bool isCenter = false,
      int? age,
      String? profession,
      double? distance,
      String? timeAgo,
      bool isOnline = false,
      String? networkingCategory,
    }) {
      final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
      final gradientColors = getAvatarGradient(userName);
      final firstName = userName.split(' ').first;

      final bgGradient = BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

      final placeholderWidget = Container(
        decoration: bgGradient,
        child: Center(
          child: Text(
            userInitial,
            style: const TextStyle(fontFamily: 'Poppins', 
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );

      final bool isAssetImage =
          imageUrl != null && imageUrl.startsWith('assets/');
      final bool isGooglePhoto =
          imageUrl != null && imageUrl.contains('googleusercontent.com');
      Widget imageWidget;
      if (isAssetImage) {
        imageWidget = SizedBox.expand(
          child: Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => placeholderWidget,
          ),
        );
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        imageWidget = CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (context, url) => placeholderWidget,
          errorWidget: (context, url, error) {
            if (error.toString().contains('429')) {
              PhotoUrlHelper.markAsRateLimited(url);
            }
            return placeholderWidget;
          },
          imageBuilder: (context, imageProvider) {
            final child = SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  image:
                      DecorationImage(image: imageProvider, fit: BoxFit.cover),
                ),
              ),
            );
            if (isGooglePhoto) {
              return ClipRect(
                  child: Transform.scale(scale: 1.5, child: child));
            }
            return child;
          },
        );
      } else {
        imageWidget = placeholderWidget;
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              if (isCenter)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image fills entire card
                Positioned.fill(
                  child: imageWidget,
                ),

                // Networking category badge top-left
                if (networkingCategory != null &&
                    networkingCategory.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            networkingCategory,
                            style: const TextStyle(fontFamily: 'Poppins', 
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Time ago badge top-right
                if (timeAgo != null && timeAgo.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            timeAgo,
                            style: const TextStyle(fontFamily: 'Poppins', 
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Glassmorphism info card at bottom
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Name + age + online dot
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    age != null
                                        ? '$firstName, $age'
                                        : firstName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'Poppins', 
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFF00E676)
                                        : Colors.grey.shade500,
                                    shape: BoxShape.circle,
                                    boxShadow: isOnline
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00E676)
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            // Profession
                            if (profession != null && profession.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  profession,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Poppins', 
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            // Distance
                            if (distance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      distance < 1
                                          ? '${(distance * 1000).toInt()} m'
                                          : '${distance.toStringAsFixed(1)} km',
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Subtle top-right shine for color cards
                if (isCenter)
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildRequestCard({
      required BuildContext context,
      required String userId,
      required String name,
      required String? photo,
      required dynamic age,
      required String? occupation,
      required double? otherLat,
      required double? otherLng,
      required double? myLat,
      required double? myLng,
      required String timeAgo,
      required bool isSent,
      required String requestId,
      required ConnectionService connectionService,
    }) {
      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

      // Calculate distance string
      String? distanceStr;
      if (myLat != null &&
          myLng != null &&
          otherLat != null &&
          otherLng != null) {
        final km = calcDistance(myLat, myLng, otherLat, otherLng);
        if (km < 1) {
          distanceStr = '${(km * 1000).round()} m';
        } else {
          distanceStr = '${km.toStringAsFixed(1)} km';
        }
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP: Profile image — scale up to crop past circular edges
            SizedBox(
              height: 100,
              width: double.infinity,
              child: photo != null && photo.isNotEmpty
                  ? ClipRect(
                      child: Transform.scale(
                        scale: 1.35,
                        child: Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(
                              0xFF016CFF,
                            ).withValues(alpha: 0.3),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF016CFF).withValues(alpha: 0.3),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(fontFamily: 'Poppins', 
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
            // BOTTOM: Info + buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontFamily: 'Poppins', 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                  // Profession
                  if (occupation != null && occupation.isNotEmpty)
                    Text(
                      occupation,
                      style: TextStyle(fontFamily: 'Poppins', 
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  // Age (left) + Distance (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (age != null)
                        Text(
                          '$age yrs',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      if (distanceStr != null)
                        Text(
                          distanceStr,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            debugPrint(
                              'Confirm tapped: requestId=$requestId, isSent=$isSent, userId=$userId',
                            );
                            final result = await connectionService
                                .acceptConnectionRequest(requestId);
                            debugPrint('Accept result: $result');
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              // Update Discover & Smart Connect tabs
                              _discoverConnectKey.currentState
                                  ?.updateConnectionCache(userId, true);
                              _smartConnectKey.currentState
                                  ?.updateConnectionCache(userId, true);
                              // Navigate to profile detail with chat button
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileDetailScreen(
                                    user: ExtendedUserProfile(
                                      uid: userId,
                                      name: name,
                                      photoUrl: photo,
                                      age: age is int
                                          ? age
                                          : int.tryParse('$age'),
                                      occupation: occupation,
                                      latitude: otherLat,
                                      longitude: otherLng,
                                    ),
                                    connectionStatus: 'connected',
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Failed', style: const TextStyle(fontFamily: 'Poppins')),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF016CFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Confirm',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            if (isSent) {
                              await connectionService.cancelConnectionRequest(
                                requestId,
                              );
                            } else {
                              await connectionService.rejectConnectionRequest(
                                requestId,
                              );
                            }
                          },
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Delete',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // My Network tab — shows confirmed/accepted connections (5-column mosaic)
    Widget buildMyNetworkTab() {
      final connectionService = ConnectionService();
      final currentUid = _auth.currentUser?.uid;


      String? resolveName(Map<String, dynamic> data) {
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty && name != 'User' && name != 'Unknown') return name;
        final displayName = data['displayName'] as String?;
        if (displayName != null && displayName.isNotEmpty && displayName != 'User' && displayName != 'Unknown') return displayName;
        final phone = data['phone'] as String?;
        if (phone != null && phone.isNotEmpty) return phone;
        return null;
      }

      return FutureBuilder<DocumentSnapshot>(
        future: currentUid != null
            ? _firestore.collection('users').doc(currentUid).get()
            : null,
        builder: (context, mySnap) {
          final myData = mySnap.data?.data() as Map<String, dynamic>?;
          final myLat = (myData?['latitude'] as num?)?.toDouble();
          final myLng = (myData?['longitude'] as num?)?.toDouble();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: connectionService.getAcceptedAsReceiverStream(),
            builder: (context, receiverSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: connectionService.getAcceptedAsSenderStream(),
                builder: (context, senderSnap) {
                  if (receiverSnap.connectionState == ConnectionState.waiting &&
                      senderSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (receiverSnap.hasError || senderSnap.hasError) {
                    final error = (receiverSnap.error ?? senderSnap.error)
                        .toString();
                    return Center(
                      child: Text(
                        'Error: $error',
                        style: TextStyle(fontFamily: 'Poppins', 
                          color: Colors.red.shade300,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  final asReceiver = receiverSnap.data ?? [];
                  final asSender = senderSnap.data ?? [];

                  // Deduplicate by otherUserId to avoid showing same person twice
                  final seen = <String>{};
                  final connections = <Map<String, dynamic>>[];
                  for (final conn in [...asReceiver, ...asSender]) {
                    final senderId = conn['senderId'] as String?;
                    final receiverId = conn['receiverId'] as String?;
                    final otherUserId = senderId == currentUid
                        ? receiverId
                        : senderId;
                    if (otherUserId != null && seen.add(otherUserId)) {
                      connections.add(conn);
                    }
                  }

                  connections.sort((a, b) {
                    final aTime =
                        a['updatedAt'] as Timestamp? ??
                        a['createdAt'] as Timestamp?;
                    final bTime =
                        b['updatedAt'] as Timestamp? ??
                        b['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  if (connections.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No connections yet',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Accepted connections will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  bool isColorCard(int index) => index % 3 == 0;

                  Widget buildCardAt(int index) {
                    final conn = connections[index];
                    final updatedAt =
                        conn['updatedAt'] as Timestamp? ??
                        conn['createdAt'] as Timestamp?;
                    final timeAgo = updatedAt != null
                        ? formatTimeAgo(updatedAt.toDate())
                        : '';

                    final senderId = conn['senderId'] as String;
                    final receiverId = conn['receiverId'] as String;
                    final otherUserId = senderId == currentUid
                        ? receiverId
                        : senderId;

                    final storedName = senderId == currentUid
                        ? conn['receiverName'] as String?
                        : conn['senderName'] as String?;
                    final storedPhoto = senderId == currentUid
                        ? conn['receiverPhoto'] as String?
                        : conn['senderPhoto'] as String?;
                    final storedAge = senderId == currentUid
                        ? conn['receiverAge']
                        : conn['senderAge'];
                    final storedOccupation = senderId == currentUid
                        ? conn['receiverOccupation'] as String?
                        : conn['senderOccupation'] as String?;
                    final storedLat = senderId == currentUid
                        ? (conn['receiverLatitude'] as num?)?.toDouble()
                        : (conn['senderLatitude'] as num?)?.toDouble();
                    final storedLng = senderId == currentUid
                        ? (conn['receiverLongitude'] as num?)?.toDouble()
                        : (conn['senderLongitude'] as num?)?.toDouble();


                    // Calculate stored distance for fallback
                    double? storedDist;
                    if (myLat != null && myLng != null &&
                        storedLat != null && storedLng != null) {
                      storedDist = calcDistance(myLat, myLng, storedLat, storedLng);
                    }
                    final storedAgeInt = storedAge is int
                        ? storedAge
                        : int.tryParse('${storedAge ?? ''}');

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                      builder: (context, userSnap) {
                        if (userSnap.connectionState ==
                            ConnectionState.waiting) {
                          final fallbackPhoto = storedPhoto != null
                              ? PhotoUrlHelper.fixGooglePhotoUrl(storedPhoto)
                              : null;
                          return buildNetworkMosaicCard(
                            userName: storedName ?? 'Loading...',
                            imageUrl: fallbackPhoto,
                            height: 145.0,
                            isCenter: isColorCard(index),
                            onTap: () {},
                            age: storedAgeInt,
                            profession: storedOccupation,
                            distance: storedDist,
                            timeAgo: timeAgo,
                          );
                        }
                        final userData =
                            userSnap.data?.data() as Map<String, dynamic>? ??
                            {};
                        final name = resolveName(userData) ??
                            storedName ?? 'Unknown';
                        final photo =
                            userData['photoUrl'] as String? ?? storedPhoto;
                        final fetchedAge = userData['age'] ?? storedAge;
                        final occupation =
                            userData['occupation'] as String? ??
                            storedOccupation;
                        final userLat =
                            (userData['latitude'] as num?)?.toDouble() ??
                            storedLat;
                        final userLng =
                            (userData['longitude'] as num?)?.toDouble() ??
                            storedLng;
                        final isOnline =
                            userData['isOnline'] as bool? ?? false;
                        final networkingCat =
                            userData['networkingCategory'] as String?;

                        double? fetchedDist;
                        if (myLat != null && myLng != null &&
                            userLat != null && userLng != null) {
                          fetchedDist = calcDistance(
                            myLat, myLng, userLat, userLng,
                          );
                        }

                        final fixedPhoto = photo != null
                            ? PhotoUrlHelper.fixGooglePhotoUrl(photo)
                            : null;

                        return buildNetworkMosaicCard(
                          userName: name,
                          imageUrl: fixedPhoto,
                          height: 145.0,
                          isCenter: isColorCard(index),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileDetailScreen(
                                  user: ExtendedUserProfile(
                                    uid: otherUserId,
                                    name: name,
                                    photoUrl: fixedPhoto,
                                    age: fetchedAge is int
                                        ? fetchedAge
                                        : int.tryParse('${fetchedAge ?? ''}'),
                                    occupation: occupation,
                                    latitude: userLat,
                                    longitude: userLng,
                                    distance: fetchedDist,
                                  ),
                                  connectionStatus: 'connected',
                                ),
                              ),
                            ).then((_) {
                              // Refresh Discover tabs when returning (handles disconnect)
                              _discoverConnectKey.currentState?.refreshPeople();
                              _smartConnectKey.currentState?.refreshPeople();
                            });
                          },
                          onMessage: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EnhancedChatScreen(
                                  otherUser: UserProfile(
                                    uid: otherUserId,
                                    name: name,
                                    email: '',
                                    profileImageUrl: fixedPhoto,
                                    location: '',
                                    latitude: userLat,
                                    longitude: userLng,
                                    createdAt: DateTime.now(),
                                    lastSeen: DateTime.now(),
                                    isOnline: isOnline,
                                  ),
                                  source: 'Networking',
                                ),
                              ),
                            );
                          },
                          age: fetchedAge is int
                              ? fetchedAge
                              : int.tryParse('${fetchedAge ?? ''}'),
                          profession: occupation,
                          distance: fetchedDist,
                          timeAgo: timeAgo,
                          isOnline: isOnline,
                          networkingCategory: networkingCat,
                        );
                      },
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 90),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: connections.length,
                    itemBuilder: (context, index) => FloatingCard(
                      animationIndex: index,
                      child: buildCardAt(index),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    }

    // Requests tab — shows pending connection requests
    Widget buildRequestsTab() {
      final connectionService = ConnectionService();
      final currentUid = _auth.currentUser?.uid;
      // First fetch current user's location for distance calculation
      return FutureBuilder<DocumentSnapshot>(
        future: currentUid != null
            ? _firestore.collection('users').doc(currentUid).get()
            : null,
        builder: (context, mySnap) {
          final myData = mySnap.data?.data() as Map<String, dynamic>?;
          final myLat = (myData?['latitude'] as num?)?.toDouble();
          final myLng = (myData?['longitude'] as num?)?.toDouble();

          // Only show received requests (requests sent TO current user)
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: connectionService.getPendingRequestsStream(),
            builder: (context, receivedSnapshot) {
                  if (receivedSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  // Show errors
                  if (receivedSnapshot.hasError) {
                    final error = receivedSnapshot.error.toString();
                    debugPrint('Requests tab error: $error');
                    if (error.contains('index') ||
                        error.contains('FAILED_PRECONDITION')) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.build_rounded,
                                size: 60,
                                color: Colors.orange.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Firestore index required',
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check console logs for the index creation link.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Poppins', 
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: Text(
                        'Error: $error',
                        style: TextStyle(fontFamily: 'Poppins', 
                          color: Colors.red.shade300,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  // Only show received requests (not sent ones)
                  // Deduplicate by senderId to avoid showing same person twice
                  final seenSenders = <String>{};
                  final requests = (receivedSnapshot.data ?? []).where((req) {
                    final senderId = req['senderId'] as String?;
                    if (senderId == null) return true;
                    return seenSenders.add(senderId);
                  }).toList();
                  // Sort by createdAt descending
                  requests.sort((a, b) {
                    final aTime = a['createdAt'] as Timestamp?;
                    final bTime = b['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime);
                  });

                  if (requests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_disabled_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending requests',
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When someone sends you a connect request,\nit will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', 
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return MasonryGridView.count(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final isSent = request['requestType'] == 'sent';
                      final requestId = request['id'] as String;
                      final createdAt = request['createdAt'] as Timestamp?;
                      final timeAgo = createdAt != null
                          ? formatTimeAgo(createdAt.toDate())
                          : '';

                      // Get the other user's ID to fetch their profile
                      final otherUserId = isSent
                          ? request['receiverId'] as String
                          : request['senderId'] as String;

                      // Check if we already have name/photo from the request doc
                      final storedName = isSent
                          ? request['receiverName'] as String?
                          : request['senderName'] as String?;
                      final storedPhoto = isSent
                          ? request['receiverPhoto'] as String?
                          : request['senderPhoto'] as String?;
                      final storedAge = isSent
                          ? request['receiverAge']
                          : request['senderAge'];
                      final storedOccupation = isSent
                          ? request['receiverOccupation'] as String?
                          : request['senderOccupation'] as String?;
                      final storedLat = isSent
                          ? (request['receiverLatitude'] as num?)?.toDouble()
                          : (request['senderLatitude'] as num?)?.toDouble();
                      final storedLng = isSent
                          ? (request['receiverLongitude'] as num?)?.toDouble()
                          : (request['senderLongitude'] as num?)?.toDouble();

                      // If name looks like a UID (no stored name), fetch from Firestore
                      final needsFetch =
                          storedName == null ||
                          storedName.isEmpty ||
                          storedName.length > 30;

                      if (needsFetch) {
                        // Fetch user profile for old requests that don't have stored info
                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('users')
                              .doc(otherUserId)
                              .get(),
                          builder: (context, userSnap) {
                            if (userSnap.connectionState ==
                                ConnectionState.waiting) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white38,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            final userData =
                                userSnap.data?.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final name =
                                userData['name'] as String? ?? 'Unknown';
                            final photo = userData['photoUrl'] as String?;
                            final age = userData['age'];
                            final occupation =
                                userData['occupation'] as String?;
                            final userLat = (userData['latitude'] as num?)
                                ?.toDouble();
                            final userLng = (userData['longitude'] as num?)
                                ?.toDouble();
                            return buildRequestCard(
                              context: context,
                              userId: otherUserId,
                              name: name,
                              photo: photo,
                              age: age,
                              occupation: occupation,
                              otherLat: userLat,
                              otherLng: userLng,
                              myLat: myLat,
                              myLng: myLng,
                              timeAgo: timeAgo,
                              isSent: isSent,
                              requestId: requestId,
                              connectionService: connectionService,
                            );
                          },
                        );
                      }

                      return buildRequestCard(
                        context: context,
                        userId: otherUserId,
                        name: storedName,
                        photo: storedPhoto,
                        age: storedAge,
                        occupation: storedOccupation,
                        otherLat: storedLat,
                        otherLng: storedLng,
                        myLat: myLat,
                        myLng: myLng,
                        timeAgo: timeAgo,
                        isSent: isSent,
                        requestId: requestId,
                        connectionService: connectionService,
                      );
                    },
                  );
            }, // StreamBuilder builder
          ); // StreamBuilder
        }, // FutureBuilder builder
      ); // FutureBuilder
    }

    // Create bottom navigation bar widget with gradient like AppBar
    Widget buildBottomNavBar() {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.fromRGBO(40, 40, 40, 1),
                  Color.fromRGBO(64, 64, 64, 1),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Colors.white, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                      icon: Icons.explore,
                      label: 'Nearby',
                      index: 4,
                      isActive: _currentIndex == 4,
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
      // If user has no networking profile, show onboarding screen
      if (_networkingProfileCount == 0) {
        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: const LiveConnectScreen(),
          bottomNavigationBar: buildBottomNavBar(),
        );
      }
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          toolbarHeight: 56,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leadingWidth: 56,
          leading: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyNetworkingProfileScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('networking_profiles')
                      .doc(_auth.currentUser?.uid)
                      .snapshots(),
                  builder: (ctx, snap) {
                    final photoUrl =
                        snap.data?.data()?['photoUrl'] as String?;
                    return Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: ClipOval(
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: Colors.white54,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          title: const Text(
            'Networking',
            style: TextStyle(fontFamily: 'Poppins', 
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            // Pending requests icon with badge
            StreamBuilder<int>(
              stream: ConnectionService().getPendingRequestsCountStream(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PendingRequestsScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: 44,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  style: const TextStyle(fontFamily: 'Poppins', 
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Filter icon — only on Smart Connect tab
            if (_networkingTabIndex == 1)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Call showFilterDialog on the active tab's LiveConnectTabScreen
                    if (_networkingTabIndex == 0) {
                      _discoverConnectKey.currentState?.showFilterDialog();
                    } else {
                      _smartConnectKey.currentState?.showFilterDialog();
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _networkingTabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Discover All'),
                  Tab(text: 'Smart Connect'),
                  Tab(text: 'My Network'),
                ],
              ),
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(40, 40, 40, 1),
                  Color.fromRGBO(64, 64, 64, 1),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 0.5),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(0, 0, 0, 1),
              ],
            ),
          ),
          child: TabBarView(
            controller: _networkingTabController,
            children: [
              LiveConnectTabScreen(
                key: _discoverConnectKey,
                activateNetworkingFilter: false,
              ),
              LiveConnectTabScreen(
                key: _smartConnectKey,
                activateNetworkingFilter: true,
              ),
              buildMyNetworkTab(),
            ],
          ),
        ),
        floatingActionButton: (_networkingTabIndex == 2 || _networkingProfileCount >= 3)
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FloatingActionButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final navigator = Navigator.of(context);
                    if (!mounted) return;
                    final tabNames = ['Discover All', 'Smart Connect', null];
                    final currentTab = tabNames[_networkingTabIndex];
                    final saved = await navigator.push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CreateNetworkingProfileScreen(
                          createdFrom: currentTab,
                        ),
                      ),
                    );
                    if (saved == true) {
              
                      _discoverConnectKey.currentState?.refreshPeople();
                      _smartConnectKey.currentState?.refreshPeople();
                    }
                  },
                  backgroundColor: const Color(0xFF007AFF),
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }
    if (_currentIndex == 4) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: NearByScreen(
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
          // Load conversation from history (SingleTap style)
          await HomeScreen.globalKey.currentState?.loadConversation(chatId);
          // Navigate to home screen
          setState(() => _currentIndex = 0);
        },
        onNewChatInProject: (projectId) {
          // Start a new chat linked to a project
          HomeScreen.globalKey.currentState?.startNewChatInProject(projectId);
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
              'SingleTap',
              style: TextStyle(fontFamily: 'Poppins', 
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
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
            width: 20,
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
              style: TextStyle(fontFamily: 'Poppins', 
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
      behavior: HitTestBehavior.translucent,
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
