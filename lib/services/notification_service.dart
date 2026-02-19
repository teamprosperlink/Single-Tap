import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_profile.dart';
import '../screens/chat/enhanced_chat_screen.dart';
import '../screens/call/voice_call_screen.dart';
import '../screens/call/group_audio_call_screen.dart';
import '../screens/call/incoming_group_audio_call_screen.dart';
import 'active_chat_service.dart';

/// Global navigator key for notification navigation
/// Set this in main.dart MaterialApp
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Callback type for handling notification navigation
typedef NotificationNavigationCallback =
    void Function(String type, Map<String, dynamic> data);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ActiveChatService _activeChatService = ActiveChatService();

  String? _fcmToken;

  /// Track shown notifications to prevent duplicates
  final Set<String> _shownNotificationIds = {};

  /// Track recent notification content to prevent duplicate displays within 5 seconds
  final Map<String, DateTime> _recentNotifications = {};

  /// Optional callback for custom navigation handling
  NotificationNavigationCallback? onNotificationTap;

  Future<void> initialize() async {
    try {
      await _requestPermissions();
      await _configureLocalNotifications();
      await _configureFCM();
      await _updateFCMToken();
      await _initializeCallKit();

      // Note: Group call listener is started from MainNavigationScreen after user login
    } catch (e) {
      // Continue app execution even if notifications fail
    }
  }

  /// Initialize CallKit for full-screen incoming call UI
  Future<void> _initializeCallKit() async {
    try {
      // Listen for CallKit events (Accept, Decline, etc.)
      FlutterCallkitIncoming.onEvent.listen(
        (CallEvent? event) async {
          try {
            if (event == null) return;

            debugPrint('  CallKit Event: ${event.event}');

            try {
              final extra = event.body['extra'] as Map<dynamic, dynamic>?;
              final callId = extra?['callId'] as String?;
              final callerId = extra?['callerId'] as String?;
              final callerName = extra?['callerName'] as String? ?? 'Unknown';
              final callerPhoto = extra?['callerPhoto'] as String?;

              switch (event.event) {
                case Event.actionCallAccept:
                  // User accepted the call - navigate to voice call screen
                  debugPrint('  CallKit: Call accepted - callId=$callId');
                  if (callId != null && callerId != null) {
                    await _handleCallAccepted(
                      callId: callId,
                      callerId: callerId,
                      callerName: callerName,
                      callerPhoto: callerPhoto,
                    );
                  }
                  break;

                case Event.actionCallDecline:
                  // User declined the call - update Firestore
                  debugPrint('  CallKit: Call declined - callId=$callId');
                  if (callId != null) {
                    await _handleCallDeclined(
                      callId: callId,
                      callerId: callerId ?? '',
                    );
                  }
                  break;

                case Event.actionCallTimeout:
                  // Call timed out - mark as missed
                  debugPrint('  CallKit: Call timeout - callId=$callId');
                  if (callId != null) {
                    await _handleCallMissed(
                      callId: callId,
                      callerId: callerId ?? '',
                      callerName: callerName,
                    );
                  }
                  break;

                case Event.actionCallEnded:
                  // Call ended
                  debugPrint('  CallKit: Call ended - callId=$callId');
                  break;

                default:
                  break;
              }
            } catch (e) {
              debugPrint('  Error extracting CallKit event data: $e');
            }
          } catch (e) {
            debugPrint('  Error handling CallKit event: $e');
          }
        },
        onError: (e) {
          debugPrint('  CallKit stream error: $e');
        },
      );

      // Check if app was launched by accepting a call
      try {
        final calls = await FlutterCallkitIncoming.activeCalls();
        if (calls is List && calls.isNotEmpty) {
          debugPrint(
            '  CallKit: Found ${calls.length} active calls on startup',
          );
        }
      } catch (e) {
        debugPrint('  Error checking active calls: $e');
      }
    } catch (e) {
      debugPrint('  Error initializing CallKit: $e');
    }
  }

  /// Handle call accepted from CallKit
  Future<void> _handleCallAccepted({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
  }) async {
    try {
      debugPrint(
        '  _handleCallAccepted: Starting - callId=$callId, callerId=$callerId',
      );

      // Check if this is a group call
      final groupCallDoc = await _firestore
          .collection('group_calls')
          .doc(callId)
          .get();
      final isGroupCall = groupCallDoc.exists;

      if (isGroupCall) {
        // Handle group call acceptance
        debugPrint('  _handleCallAccepted: This is a GROUP call');

        final groupCallData = groupCallDoc.data();
        debugPrint('  _handleCallAccepted: Group call data fetched');

        final groupId = groupCallData?['groupId'] as String?;
        final groupName = groupCallData?['groupName'] as String?;
        final participantIds =
            groupCallData?['participants'] as List<dynamic>? ?? [];

        debugPrint(
          '  _handleCallAccepted: groupId=$groupId, groupName=$groupName, participants=${participantIds.length}',
        );

        if (groupId == null) {
          debugPrint(
            '  _handleCallAccepted: ERROR - No groupId in group call data',
          );
          return;
        }

        // Get current user ID
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) {
          debugPrint('  _handleCallAccepted: ERROR - No current user');
          return;
        }

        debugPrint('  _handleCallAccepted: currentUserId=$currentUserId');

        // IMMEDIATE NAVIGATION - SingleTap-like instant call screen
        // Dismiss CallKit and navigate FIRST, then update status in background
        debugPrint(
          '  _handleCallAccepted: Navigating IMMEDIATELY to call screen...',
        );

        if (navigatorKey.currentState != null) {
          // Dismiss CallKit UI IMMEDIATELY (async, no wait)
          FlutterCallkitIncoming.endCall(callId)
              .then((_) {
                debugPrint('  _handleCallAccepted: CallKit UI dismissed');
              })
              .catchError((e) {
                debugPrint(
                  '  _handleCallAccepted: Error dismissing CallKit UI: $e',
                );
              });

          // Navigate INSTANTLY with minimal data - GroupAudioCallScreen will fetch details
          navigatorKey.currentState!.push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return GroupAudioCallScreen(
                  callId: callId,
                  groupId: groupId,
                  groupName: groupName ?? 'Unknown Group',
                  userId: currentUserId,
                  userName: _auth.currentUser?.displayName ?? 'Unknown',
                  participants: [], // Empty - screen will fetch from Firestore
                );
              },
              transitionDuration: Duration.zero, // Instant transition
              reverseTransitionDuration: Duration.zero,
            ),
          );

          debugPrint(
            '  _handleCallAccepted: Navigation initiated! Updating status in background...',
          );

          // Update status in background (don't block navigation)
          _updateGroupCallStatusInBackground(callId, currentUserId);
        } else {
          debugPrint(
            '  _handleCallAccepted: ERROR - navigatorKey.currentState is NULL!',
          );
        }
      } else {
        // Handle regular 1-on-1 call
        debugPrint('  _handleCallAccepted: This is a REGULAR 1-on-1 call');

        // Update call status in Firestore
        try {
          await _firestore.collection('calls').doc(callId).update({
            'status': 'connected',
            'acceptedAt': FieldValue.serverTimestamp(),
            'connectedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('  _handleCallAccepted: Call status updated to connected');
        } catch (e) {
          debugPrint('  _handleCallAccepted: Error updating call status: $e');
        }

        // Fetch caller profile for VoiceCallScreen
        UserProfile callerProfile;
        try {
          final callerDoc = await _firestore
              .collection('users')
              .doc(callerId)
              .get();
          if (callerDoc.exists) {
            callerProfile = UserProfile.fromFirestore(callerDoc);
            debugPrint(
              '  _handleCallAccepted: Fetched caller profile: ${callerProfile.name}',
            );
          } else {
            callerProfile = UserProfile(
              uid: callerId,
              id: callerId,
              name: callerName,
              email: '',
              profileImageUrl: callerPhoto,
              createdAt: DateTime.now(),
              lastSeen: DateTime.now(),
            );
            debugPrint(
              '  _handleCallAccepted: Created fallback caller profile',
            );
          }
        } catch (e) {
          debugPrint(
            '  _handleCallAccepted: Error fetching caller profile: $e',
          );
          callerProfile = UserProfile(
            uid: callerId,
            id: callerId,
            name: callerName,
            email: '',
            profileImageUrl: callerPhoto,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
          );
        }

        // Dismiss CallKit UI IMMEDIATELY (no await) for SingleTap-like smooth transition
        FlutterCallkitIncoming.endCall(callId)
            .then((_) {
              debugPrint('  _handleCallAccepted: CallKit UI dismissed');
            })
            .catchError((e) {
              debugPrint(
                '  _handleCallAccepted: Error dismissing CallKit UI: $e',
              );
            });

        // Navigate INSTANTLY to VoiceCallScreen with zero transition delay
        try {
          if (navigatorKey.currentState != null) {
            debugPrint(
              '  _handleCallAccepted: Navigating to VoiceCallScreen with callerProfile: ${callerProfile.name} (${callerProfile.uid})',
            );
            // Use pushReplacement to avoid underlying page refresh
            navigatorKey.currentState!.pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return VoiceCallScreen(
                    callId: callId,
                    otherUser: callerProfile,
                    isOutgoing: false,
                  );
                },
                transitionDuration: Duration.zero, // Instant transition
                reverseTransitionDuration: Duration.zero,
              ),
            );
            debugPrint(
              '  _handleCallAccepted: Navigation to VoiceCallScreen initiated!',
            );
          } else {
            debugPrint(
              '  _handleCallAccepted: WARNING - navigatorKey.currentState is null!',
            );
          }
        } catch (e) {
          debugPrint('  _handleCallAccepted: Error navigating: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('  Error handling call accept: $e');
      debugPrint('  Stack trace: $stackTrace');
    }
  }

  /// Update group call status in background (don't block navigation)
  void _updateGroupCallStatusInBackground(String callId, String currentUserId) {
    debugPrint(
      '  _updateGroupCallStatusInBackground: Starting for callId=$callId, userId=$currentUserId',
    );

    // Run asynchronously without blocking
    Future(() async {
      try {
        // Update call status to connected
        await _firestore.collection('group_calls').doc(callId).update({
          'status': 'connected',
          'acceptedAt': FieldValue.serverTimestamp(),
          'connectedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
          '  _updateGroupCallStatusInBackground: Call status updated to connected',
        );

        // Update participant status to joined
        await _firestore.collection('group_calls').doc(callId).update({
          'participants.$currentUserId.status': 'joined',
          'participants.$currentUserId.joinedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
          '  _updateGroupCallStatusInBackground: Participant status updated to joined',
        );
      } catch (e) {
        debugPrint(
          '  _updateGroupCallStatusInBackground: Error updating call status: $e',
        );
      }
    });
  }

  /// Handle call declined from CallKit
  Future<void> _handleCallDeclined({
    required String callId,
    required String callerId,
  }) async {
    try {
      // Check if this is a group call
      final groupCallDoc = await _firestore
          .collection('group_calls')
          .doc(callId)
          .get();
      final isGroupCall = groupCallDoc.exists;

      if (isGroupCall) {
        // Update group call status
        await _firestore.collection('group_calls').doc(callId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('  Group call declined: $callId');
      } else {
        // Update regular call status
        await _firestore.collection('calls').doc(callId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('  Regular call declined: $callId');
      }

      // End the CallKit call UI
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('  Error handling call decline: $e');
    }
  }

  /// Handle call missed (timeout) from CallKit
  Future<void> _handleCallMissed({
    required String callId,
    required String callerId,
    required String callerName,
  }) async {
    try {
      // Check if this is a group call
      final groupCallDoc = await _firestore
          .collection('group_calls')
          .doc(callId)
          .get();
      final isGroupCall = groupCallDoc.exists;

      if (isGroupCall) {
        // Handle group call missed
        final currentStatus = groupCallDoc.data()?['status'] as String?;
        debugPrint(
          '  _handleCallMissed (GROUP): Current status = $currentStatus',
        );

        if (currentStatus == 'ringing' || currentStatus == 'connected') {
          debugPrint(
            '  _handleCallMissed: Group call is $currentStatus, NOT marking as missed',
          );
          await FlutterCallkitIncoming.endCall(callId);
          return;
        }

        // Mark group call as missed
        await _firestore.collection('group_calls').doc(callId).update({
          'status': 'missed',
          'missedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Handle regular call missed
        final callDoc = await _firestore.collection('calls').doc(callId).get();
        if (callDoc.exists) {
          final currentStatus = callDoc.data()?['status'] as String?;
          debugPrint(
            '  _handleCallMissed (REGULAR): Current status = $currentStatus',
          );

          if (currentStatus == 'ringing' || currentStatus == 'connected') {
            debugPrint(
              '  _handleCallMissed: Call is $currentStatus, NOT marking as missed',
            );
            await FlutterCallkitIncoming.endCall(callId);
            return;
          }
        }

        // Mark regular call as missed
        await _firestore.collection('calls').doc(callId).update({
          'status': 'missed',
          'missedAt': FieldValue.serverTimestamp(),
        });
      }

      // End the CallKit call UI
      await FlutterCallkitIncoming.endCall(callId);

      // Show missed call notification
      _showMissedCallLocalNotification(callerName);
    } catch (e) {
      debugPrint('  Error handling call missed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // Request FCM permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request Android-specific permissions for calls and notifications
    if (!kIsWeb && Platform.isAndroid) {
      await _requestAndroidPermissions();
    }
  }

  /// Request all Android permissions needed for SingleTap-style incoming calls
  Future<void> _requestAndroidPermissions() async {
    try {
      // Android 13+ requires POST_NOTIFICATIONS permission
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        final result = await Permission.notification.request();
        debugPrint('  Notification permission: $result');
      }

      // Request microphone for voice calls (essential)
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final result = await Permission.microphone.request();
        debugPrint('  Microphone permission: $result');
      }

      // Note: Phone permission and battery optimization are optional
      // They may be denied on some devices - that's okay
      // The app will still work with notifications and CallKit

      debugPrint(
        '  Essential Android permissions requested for incoming calls',
      );
    } catch (e) {
      debugPrint('  Error requesting Android permissions: $e');
    }
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (androidPlugin != null) {
          // Chat messages channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'chat_messages',
              'Chat Messages',
              description: 'Notifications for new chat messages',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Call channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'calls',
              'Incoming Calls',
              description: 'Notifications for incoming voice calls',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Inquiries channel (for professionals)
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'inquiries',
              'Service Inquiries',
              description: 'Notifications for new service inquiries',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );

          // Connection requests channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'connections',
              'Connection Requests',
              description: 'Notifications for connection requests',
              importance: Importance.defaultImportance,
              playSound: true,
            ),
          );
        }
      }
    } catch (e) {
      // Error creating notification channels
    }
  }

  Future<void> _configureFCM() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Handle when app is launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Delay navigation to ensure app is fully loaded
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleNotificationOpen(initialMessage);
      });
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();

      if (_fcmToken != null && _auth.currentUser != null) {
        // Add a small delay to ensure Firestore auth is ready
        await Future.delayed(const Duration(milliseconds: 500));

        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {
            'fcmToken': _fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          },
        );
      }
    } catch (e) {
      // Continue without crashing the app
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        _fcmToken = newToken;
        if (_auth.currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .update({
                'fcmToken': newToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              });
        }
      } catch (e) {
        // Error refreshing FCM token
      }
    });
  }

  /// Handle messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    // CRITICAL FIX: For call notifications, ALWAYS show full-screen CallKit UI
    // Even when app is in foreground (both devices active)
    // This ensures SingleTap-style incoming call experience
    if (type == 'call') {
      debugPrint('  FOREGROUND 1-ON-1 CALL: Showing full-screen CallKit UI');
      _navigateToCall(data); // Show full-screen incoming call
      return;
    }

    // CRITICAL FIX: For GROUP call notifications, ALWAYS show full-screen CallKit UI
    // Even when app is in foreground - SingleTap-style
    if (type == 'group_audio_call') {
      debugPrint('  FOREGROUND GROUP CALL: Showing full-screen CallKit UI');
      _navigateToGroupCall(data); // Show full-screen incoming group call
      return;
    }

    // SingleTap-style: Don't show notification for messages in the CURRENT OPEN chat
    // Check if user is currently viewing this conversation
    if (type == 'message') {
      final senderId = data['senderId'] as String?;
      final conversationId = data['conversationId'] as String?;

      // Check if this message is from the currently active chat
      if (senderId != null && _activeChatService.isUserChatActive(senderId)) {
        debugPrint(
          '  Suppressing notification: User is in chat with $senderId',
        );
        return; // Don't show notification - user is already viewing this chat
      }

      if (conversationId != null &&
          _activeChatService.isConversationActive(conversationId)) {
        debugPrint(
          '  Suppressing notification: Conversation $conversationId is active',
        );
        return; // Don't show notification - conversation is open
      }
    }

    // Show notification for all other cases
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: jsonEncode(data),
        channelId: _getChannelIdForType(type),
      );
    }
  }

  /// Handle when user taps notification and app opens from background
  void _handleNotificationOpen(RemoteMessage message) {
    final data = message.data;
    _navigateBasedOnNotificationType(data);
  }

  /// Get appropriate channel ID based on notification type
  String _getChannelIdForType(String? type) {
    switch (type) {
      case 'call':
        return 'calls';
      case 'inquiry':
        return 'inquiries';
      case 'connection_request':
        return 'connections';
      case 'message':
      default:
        return 'chat_messages';
    }
  }

  /// Navigate to appropriate screen based on notification type
  Future<void> _navigateBasedOnNotificationType(
    Map<String, dynamic> data,
  ) async {
    final type = data['type'] as String?;

    debugPrint('  🔔 Notification tapped - type: $type, data: $data');

    // If custom callback is set, use it
    if (onNotificationTap != null) {
      debugPrint('   Using custom callback for notification tap');
      onNotificationTap!(type ?? 'unknown', data);
      return;
    }

    // Default navigation handling
    switch (type) {
      case 'message':
        debugPrint('  💬 Navigating to chat');
        await _navigateToChat(data);
        break;
      case 'call':
        debugPrint('  ☎️  Navigating to call');
        await _navigateToCall(data);
        break;
      case 'group_audio_call':
        debugPrint('    Navigating to group audio call');
        await _navigateToGroupCall(data);
        break;
      case 'inquiry':
        debugPrint('  ❓ Navigating to inquiries');
        await _navigateToInquiries(data);
        break;
      case 'connection_request':
        debugPrint('  🤝 Navigating to connections');
        await _navigateToConnections(data);
        break;
      default:
        debugPrint('     Unknown notification type: $type');
        break;
    }
  }

  /// Navigate to chat screen
  Future<void> _navigateToChat(Map<String, dynamic> data) async {
    final conversationId = data['conversationId'] as String?;
    final senderId = data['senderId'] as String?;

    if (conversationId == null || senderId == null) {
      return;
    }

    try {
      // Fetch sender's profile
      final userDoc = await _firestore.collection('users').doc(senderId).get();
      if (!userDoc.exists) {
        return;
      }

      final otherUser = UserProfile.fromFirestore(userDoc);

      // Navigate using global navigator key
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => EnhancedChatScreen(otherUser: otherUser),
          ),
        );
      }
    } catch (e) {
      // Error navigating to chat
    }
  }

  /// Navigate to incoming call screen
  Future<void> _navigateToCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String? ?? 'Unknown';
    final callerPhoto = data['callerPhoto'] as String?;

    debugPrint('  _navigateToCall: callId=$callId, callerId=$callerId');

    if (callId == null || callerId == null) {
      debugPrint('  _navigateToCall: Missing callId or callerId');
      return;
    }

    // Check if call is still active before navigating
    // This handles the case when user taps notification but call was already ended/missed
    try {
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        debugPrint('  _navigateToCall: Call document does not exist');
        return;
      }

      final callData = callDoc.data();
      final callStatus = callData?['status'] as String?;
      debugPrint('  _navigateToCall: Call status = $callStatus');

      // Only show incoming call screen if call is still in 'calling' or 'ringing' state
      if (callStatus != 'calling' && callStatus != 'ringing') {
        // Call has ended - show missed call notification if it was missed
        if (callStatus == 'missed' || callStatus == 'ended') {
          debugPrint(
            '  _navigateToCall: Call already ended/missed, showing notification',
          );
          _showMissedCallLocalNotification(callerName);
        }
        return;
      }

      // Check if call is too old (more than 60 seconds)
      final timestamp = callData?['timestamp'] ?? callData?['createdAt'];
      if (timestamp is Timestamp) {
        final callTime = timestamp.toDate();
        final now = DateTime.now();
        final diff = now.difference(callTime).inSeconds;

        if (diff > 60) {
          debugPrint(
            '  _navigateToCall: Call too old ($diff seconds), marking as missed',
          );
          // Mark as missed
          await _firestore.collection('calls').doc(callId).update({
            'status': 'missed',
            'missedAt': FieldValue.serverTimestamp(),
          });
          _showMissedCallLocalNotification(callerName);
          return;
        }
      }
    } catch (e) {
      debugPrint('  _navigateToCall: Error checking call status: $e');
      // If we can't verify, skip navigation to be safe
      return;
    }

    debugPrint('  _navigateToCall: Showing CallKit incoming call UI');

    // Show CallKit incoming call UI (like SingleTap)
    // This provides full-screen native call UI
    final callKitParams = CallKitParams(
      id: callId,
      nameCaller: callerName,
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
      duration: 60000,
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

    // Update call status to ringing
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('  Error updating call status: $e');
    }
  }

  /// Show missed call notification locally
  void _showMissedCallLocalNotification(String callerName) {
    _showLocalNotification(
      title: 'Missed Call',
      body: 'You missed a call from $callerName',
      channelId: 'calls',
    );
  }

  /// Navigate to incoming group call screen
  Future<void> _navigateToGroupCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final groupId = data['groupId'] as String?;
    final groupName = data['groupName'] as String? ?? 'Unknown Group';
    final callerName = data['callerName'] as String? ?? 'Unknown';
    final callerPhoto = data['callerPhoto'] as String?;

    debugPrint(
      '  _navigateToGroupCall: callId=$callId, callerId=$callerId, groupId=$groupId',
    );

    if (callId == null || callerId == null || groupId == null) {
      debugPrint('  _navigateToGroupCall: Missing required data');
      return;
    }

    // Don't show incoming call screen to the caller
    final currentUserId = _auth.currentUser?.uid;
    if (callerId == currentUserId) {
      debugPrint(
        '  _navigateToGroupCall: Current user is the caller, skipping',
      );
      return;
    }

    // Check if call is still active before navigating
    try {
      final callDoc = await _firestore
          .collection('group_calls')
          .doc(callId)
          .get();
      if (!callDoc.exists) {
        debugPrint('  _navigateToGroupCall: Call document does not exist');
        return;
      }

      final callData = callDoc.data();
      final callStatus = callData?['status'] as String?;
      debugPrint('  _navigateToGroupCall: Call status = $callStatus');

      // Only show incoming call screen if call is still active (calling, ringing, or active)
      // Note: 'active' is included because caller sets status to active immediately
      if (callStatus != 'calling' &&
          callStatus != 'ringing' &&
          callStatus != 'active') {
        debugPrint(
          '  _navigateToGroupCall: Call already ended, status=$callStatus',
        );
        return;
      }

      // Check if call is too old (more than 60 seconds)
      final timestamp = callData?['timestamp'] ?? callData?['createdAt'];
      if (timestamp is Timestamp) {
        final callTime = timestamp.toDate();
        final now = DateTime.now();
        final diff = now.difference(callTime).inSeconds;

        if (diff > 60) {
          debugPrint(
            '  _navigateToGroupCall: Call too old ($diff seconds), skipping',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('  _navigateToGroupCall: Error checking call status: $e');
      return;
    }

    debugPrint('   _navigateToGroupCall: Showing full-screen incoming call UI');

    try {
      // Fetch all participants for the incoming call screen
      debugPrint('    Fetching participants for group call...');
      final participantsData = <Map<String, dynamic>>[];
      final participants =
          (await _firestore.collection('group_calls').doc(callId).get())
                  .data()?['participants']
              as List? ??
          [];

      for (final participantId in participants) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(participantId as String)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            participantsData.add({
              'userId': participantId,
              'name': userData?['name'] ?? 'Unknown',
              'photoUrl': userData?['photoUrl'],
            });
          }
        } catch (e) {
          debugPrint('     Error fetching participant $participantId: $e');
        }
      }

      debugPrint('    Fetched ${participantsData.length} participants');

      // Get current user ID
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        debugPrint('    Current user ID is null');
        return;
      }

      debugPrint('    Navigating to IncomingGroupAudioCallScreen');

      // Navigate to IncomingGroupAudioCallScreen (full-screen UI)
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => IncomingGroupAudioCallScreen(
              callId: callId,
              groupId: groupId,
              groupName: groupName,
              callerId: callerId,
              callerName: callerName,
              callerPhoto: callerPhoto,
              currentUserId: currentUserId,
              currentUserName: _auth.currentUser?.displayName ?? 'User',
              participants: participantsData,
            ),
          ),
        );
      }

      debugPrint('    IncomingGroupAudioCallScreen shown (full screen)');

      // Don't update call status - let it remain as is (calling or active)
      // Each user's ringing status is tracked in their participant document
    } catch (e) {
      debugPrint('    Error navigating to group call: $e');
    }
  }

  /// Navigate to inquiries screen (for professionals)
  Future<void> _navigateToInquiries(Map<String, dynamic> data) async {
    // TODO: Navigate to inquiries screen
  }

  /// Navigate to connections/requests screen
  Future<void> _navigateToConnections(Map<String, dynamic> data) async {
    // TODO: Navigate to connections screen
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'chat_messages',
  }) async {
    // Create unique key for this notification content
    final notificationKey = '$title|$body';
    final now = DateTime.now();

    // Check if same notification was shown recently (within 5 seconds)
    if (_recentNotifications.containsKey(notificationKey)) {
      final lastShown = _recentNotifications[notificationKey]!;
      final difference = now.difference(lastShown).inSeconds;

      if (difference < 5) {
        debugPrint(
          '  Skipping duplicate notification (shown $difference seconds ago): $title',
        );
        return;
      }
    }

    // Update recent notifications map
    _recentNotifications[notificationKey] = now;

    // Clean up old entries (remove entries older than 10 seconds)
    _recentNotifications.removeWhere((key, time) {
      return now.difference(time).inSeconds > 10;
    });

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'chat_messages'
          ? 'Chat Messages'
          : channelId == 'calls'
          ? 'Incoming Calls'
          : channelId == 'inquiries'
          ? 'Service Inquiries'
          : 'Notifications',
      channelDescription: 'Notification channel',
      importance: channelId == 'calls' ? Importance.max : Importance.high,
      priority: channelId == 'calls' ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateBasedOnNotificationType(data);
      } catch (e) {
        // Error parsing notification payload
      }
    }
  }

  /// Show a local notification (public API)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(title: title, body: body, payload: payload);
  }

  /// Send notification to another user via Firestore
  /// Note: For calls, the Cloud Function (onCallCreated) automatically sends FCM push
  /// Listen for incoming group calls in real-time
  /// This is a fallback for when Cloud Functions are not available
  StreamSubscription? _groupCallListener;

  void startListeningForGroupCalls() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('    startListeningForGroupCalls: currentUserId is NULL');
      return;
    }

    debugPrint('========================================');
    debugPrint('    Starting group call listener for user: $currentUserId');
    debugPrint('========================================');

    _groupCallListener = _firestore
        .collection('group_calls')
        .where('participants', arrayContains: currentUserId)
        .limit(10) // Limit to recent calls to reduce Firebase reads
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint('========================================');
            debugPrint(
              '   Group call snapshot received: ${snapshot.docs.length} docs, ${snapshot.docChanges.length} changes',
            );
            debugPrint('========================================');

            for (var change in snapshot.docChanges) {
              debugPrint('    Document change type: ${change.type}');

              if (change.type == DocumentChangeType.added) {
                final callData = change.doc.data();
                if (callData == null) {
                  debugPrint('    Call data is null');
                  continue;
                }

                final callId = change.doc.id;
                final callerId = callData['callerId'] as String?;
                final callerName = callData['callerName'] as String?;
                final groupId = callData['groupId'] as String?;
                final groupName = callData['groupName'] as String?;
                final participants = callData['participants'] as List?;
                final status = callData['status'] as String?;

                debugPrint(
                  '    Call detected: callId=$callId, callerId=$callerId, callerName=$callerName, status=$status',
                );
                debugPrint('    Participants in call: $participants');
                debugPrint(
                  '    CurrentUserId: $currentUserId, Is currentUser the caller? ${callerId == currentUserId}',
                );

                // Filter by status in code instead of query
                if (status != 'calling' &&
                    status != 'active' &&
                    status != 'connected' &&
                    status != 'ringing') {
                  debugPrint('     Skipping - call status is $status');
                  continue;
                }

                // Don't show notification to the caller
                if (callerId == currentUserId) {
                  debugPrint('     Skipping - current user is the caller');
                  continue;
                }

                debugPrint(
                  '    NEW GROUP CALL DETECTED: $callId from $callerName',
                );

                // Get caller photo
                String? callerPhoto;
                try {
                  final callerDoc = await _firestore
                      .collection('users')
                      .doc(callerId)
                      .get();
                  callerPhoto = callerDoc.data()?['photoUrl'] as String?;
                  debugPrint('    Fetched caller photo: $callerPhoto');
                } catch (e) {
                  debugPrint('    Error fetching caller photo: $e');
                }

                // Show full-screen incoming call UI (not CallKit)
                debugPrint(
                  '    Calling _navigateToGroupCall with callId=$callId, groupName=$groupName',
                );
                try {
                  await _navigateToGroupCall({
                    'callId': callId,
                    'callerId': callerId,
                    'callerName': callerName ?? 'Someone',
                    'callerPhoto': callerPhoto,
                    'groupId': groupId,
                    'groupName': groupName ?? 'Unknown Group',
                  });
                } catch (e) {
                  debugPrint('    Error in _navigateToGroupCall: $e');
                }
              } else if (change.type == DocumentChangeType.modified) {
                debugPrint('    Document modified: ${change.doc.id}');
              } else if (change.type == DocumentChangeType.removed) {
                debugPrint('     Document removed: ${change.doc.id}');
              }
            }
          },
          onError: (error) {
            debugPrint('    Group call listener error: $error');
          },
        );
  }

  void stopListeningForGroupCalls() {
    _groupCallListener?.cancel();
    _groupCallListener = null;
  }

  /// Test method to verify the listener can access group call documents
  Future<void> testGroupCallDocumentAccess() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('    testGroupCallDocumentAccess: currentUserId is NULL');
      return;
    }

    debugPrint(
      '    Testing group call document access for user: $currentUserId',
    );

    try {
      // Test 1: Can we read ANY group_calls documents?
      final allCalls = await _firestore
          .collection('group_calls')
          .limit(5)
          .get();
      debugPrint(
        '    Total group_calls documents in system: ${allCalls.docs.length}',
      );
      for (var doc in allCalls.docs) {
        final status = doc['status'];
        final participants = doc['participants'] as List?;
        debugPrint(
          '    - Doc ${doc.id}: status=$status, participants=$participants',
        );
      }

      // Test 2: Can we query with arrayContains?
      final userCalls = await _firestore
          .collection('group_calls')
          .where('participants', arrayContains: currentUserId)
          .limit(5)
          .get();
      debugPrint(
        '    Group calls where user is participant: ${userCalls.docs.length}',
      );
      for (var doc in userCalls.docs) {
        final status = doc['status'];
        final callerId = doc['callerId'];
        debugPrint('    - Doc ${doc.id}: status=$status, callerId=$callerId');
      }

      // Test 3: Can we query with compound condition?
      final activeUserCalls = await _firestore
          .collection('group_calls')
          .where('participants', arrayContains: currentUserId)
          .where('status', isEqualTo: 'calling')
          .limit(5)
          .get();
      debugPrint(
        '    Active group calls for user: ${activeUserCalls.docs.length}',
      );
      for (var doc in activeUserCalls.docs) {
        final callerId = doc['callerId'];
        final groupName = doc['groupName'];
        debugPrint(
          '    - Doc ${doc.id}: callerId=$callerId, groupName=$groupName',
        );
      }

      debugPrint('    All document access tests passed!');
    } catch (e) {
      debugPrint('    Error testing document access: $e');
      if (e.toString().contains('index')) {
        debugPrint('  💡 This might be a Firestore composite index issue');
      }
    }
  }

  /// when a call document is created in Firestore
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Store notification in Firestore for the target user
      // For calls, the Cloud Function handles FCM push automatically
      await _firestore.collection('notifications').add({
        'userId': userId,
        'senderId': currentUserId,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending notification to user: $e');
    }
  }

  /// Listen for notifications for the current user
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    // Simple query without compound index requirement
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort locally instead of in query (avoids index requirement)
          notifications.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return notifications;
        });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      // Error marking notification as read
    }
  }

  /// Process and show new notifications (call this from a listener)
  Future<void> processNewNotification(Map<String, dynamic> notification) async {
    final notificationId = notification['id'] as String?;

    // Prevent duplicate notifications - check if already shown
    if (notificationId != null &&
        _shownNotificationIds.contains(notificationId)) {
      debugPrint('  Skipping duplicate notification: $notificationId');
      return;
    }

    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';

    // Add to shown notifications set
    if (notificationId != null) {
      _shownNotificationIds.add(notificationId);
    }

    // Show local notification
    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(notification['data'] ?? {}),
      channelId: _getChannelIdForType(notification['type'] as String?),
    );

    // Mark as read after showing
    if (notificationId != null) {
      await markNotificationAsRead(notificationId);
    }

    // Clean up old entries from set (keep last 100 to prevent memory leak)
    if (_shownNotificationIds.length > 100) {
      final excess = _shownNotificationIds.length - 100;
      final toRemove = _shownNotificationIds.take(excess).toList();
      _shownNotificationIds.removeAll(toRemove);
    }
  }

  /// Clear FCM token on logout
  Future<void> clearFcmToken() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
              'fcmToken': FieldValue.delete(),
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
      }
      await _fcm.deleteToken();
      _fcmToken = null;
    } catch (e) {
      // Error clearing FCM token
    }
  }

  Future<void> updateBadgeCount(int count) async {
    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(badge: true);
      }
    } catch (e) {
      // Badge count update not supported on this platform
    }
  }

  Future<void> clearNotifications() async {
    await _localNotifications.cancelAll();
    await updateBadgeCount(0);
  }

  Future<void> clearChatNotifications(String conversationId) async {
    // Clear notifications for specific chat
    // Could be enhanced to track notification IDs per conversation
  }

  Future<int> getUnreadMessageCount() async {
    if (_auth.currentUser == null) return 0;

    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: _auth.currentUser!.uid)
          .get();

      int totalUnread = 0;
      for (var doc in conversations.docs) {
        try {
          final data = doc.data();
          final unreadCountValue =
              data['unreadCount']?[_auth.currentUser!.uid] ?? 0;

          // Safely convert to int, handling both int and string types
          int count = 0;
          if (unreadCountValue is int) {
            count = unreadCountValue;
          } else if (unreadCountValue is String) {
            count = int.tryParse(unreadCountValue) ?? 0;
          }
          totalUnread += count;
        } catch (e) {
          // Error processing individual conversation - continue to next
        }
      }

      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  /// Get current FCM token (for debugging)
  String? get fcmToken => _fcmToken;

  /// Debug method: Verify FCM token is saved in Firestore
  Future<void> verifyFCMTokenSetup() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('  No current user');
      return;
    }

    debugPrint('========================================');
    debugPrint('🔍 FCM TOKEN VERIFICATION');
    debugPrint('========================================');

    // Get local token
    final localToken = await _fcm.getToken();
    debugPrint('  Local FCM token: ${localToken?.substring(0, 20)}...');

    // Get Firestore token
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      final firestoreToken = userDoc.data()?['fcmToken'] as String?;
      debugPrint(
        '   Firestore FCM token: ${firestoreToken?.substring(0, 20)}...',
      );

      if (localToken == firestoreToken) {
        debugPrint('  Tokens match - FCM setup is correct!');
      } else {
        debugPrint('   Tokens DO NOT match - updating Firestore...');
        await _updateFCMToken();
        debugPrint('  Firestore token updated');
      }
    } catch (e) {
      debugPrint('  Error checking Firestore token: $e');
    }

    debugPrint('========================================');
  }

  /// Debug method: Test sending a notification to self
  Future<void> testSelfNotification() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      debugPrint('  No current user');
      return;
    }

    debugPrint('========================================');
    debugPrint('  TESTING SELF NOTIFICATION');
    debugPrint('========================================');

    try {
      await sendNotificationToUser(
        userId: currentUserId,
        title: 'Test Notification',
        body: 'This is a test notification from the app',
        type: 'test',
        data: {'testTime': DateTime.now().toIso8601String()},
      );

      debugPrint('  Test notification created in Firestore');
      debugPrint('  Cloud Function should send FCM in 1-2 seconds...');
      debugPrint('  Check if notification appears on device');
    } catch (e) {
      debugPrint('  Error sending test notification: $e');
    }

    debugPrint('========================================');
  }

  /// Check if all required permissions for calls are granted
  Future<bool> checkCallPermissions() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        final notificationGranted = await Permission.notification.isGranted;
        final microphoneGranted = await Permission.microphone.isGranted;

        return notificationGranted && microphoneGranted;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request all permissions needed for SingleTap-style calls (public API)
  Future<bool> requestCallPermissions() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();

        // Check if critical permissions were granted
        final notificationGranted = await Permission.notification.isGranted;
        final microphoneGranted = await Permission.microphone.isGranted;

        return notificationGranted && microphoneGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting call permissions: $e');
      return false;
    }
  }
}

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('  Background FCM message received: ${message.data}');

  final data = message.data;
  final type = data['type'] as String?;

  // Handle incoming regular 1-on-1 call in background
  if (type == 'call') {
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String? ?? 'Unknown';
    final callerPhoto = data['callerPhoto'] as String?;

    if (callId != null && callerId != null) {
      debugPrint('  Background: Showing incoming 1-on-1 call from $callerName');

      // Show SingleTap-style incoming call UI
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
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
    }
  }
  // Handle incoming GROUP call in background - SingleTap style
  else if (type == 'group_audio_call') {
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String? ?? 'Unknown';
    final callerPhoto = data['callerPhoto'] as String?;
    final groupId = data['groupId'] as String?;
    final groupName = data['groupName'] as String? ?? 'Unknown Group';

    if (callId != null && callerId != null && groupId != null) {
      debugPrint(
        '  Background: Showing incoming GROUP call from $callerName in $groupName',
      );

      // Show SingleTap-style incoming GROUP call UI with full-screen notification
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'SingleTap',
        avatar: callerPhoto,
        handle: 'Group Voice Call - $groupName',
        type: 0, // Audio call
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: false,
          subtitle: 'Missed Group Call',
          callbackText: 'Call back',
        ),
        duration: 60000, // 60 seconds timeout
        extra: <String, dynamic>{
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callerPhoto': callerPhoto,
          'groupId': groupId,
          'groupName': groupName,
          'isGroupCall': true,
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
          isShowFullLockedScreen: true, // Full-screen like SingleTap
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
    }
  }
}
