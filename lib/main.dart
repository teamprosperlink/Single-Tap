import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:supper/screens/login/onboarding_screen.dart';

import 'firebase_options.dart';
import 'screens/login/splash_screen.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/call/voice_call_screen.dart';
import 'models/user_profile.dart';

import 'services/auth_service.dart';
import 'services/profile services/profile_service.dart';
import 'services/user_manager.dart';
import 'services/notification_service.dart';
import 'services/chat services/conversation_service.dart';
import 'services/location services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/analytics_service.dart';
import 'services/error services/error_tracking_service.dart';
import 'providers/other providers/theme_provider.dart';
import 'res/utils/app_optimizer.dart';
import 'res/utils/memory_manager.dart';

// FCM background handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background isolate with error handling
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase initialization failed - log and return
    print('[FCM] Firebase init error in background handler: $e');
    return;
  }

  try {
    final data = message.data;
    final type = data['type'] as String?;

    // For call notifications, show full-screen CallKit UI (like WhatsApp)
    if (type == 'call') {
      final callId = data['callId'] as String?;
      final callerId = data['callerId'] as String?;
      final callerName = data['callerName'] as String? ?? 'Someone';
      final callerPhoto = data['callerPhoto'] as String?;

      if (callId == null) return;

      // Verify call is still active before showing notification
      try {
        final callDoc = await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .get();

        if (!callDoc.exists) return;

        final callStatus = callDoc.data()?['status'] as String?;
        // Only show notification if call is still 'calling' or 'ringing'
        if (callStatus != 'calling' && callStatus != 'ringing') return;

        // Show full-screen incoming call UI using CallKit
        await showFullScreenIncomingCall(
          callId: callId,
          callerId: callerId ?? '',
          callerName: callerName,
          callerPhoto: callerPhoto,
        );
      } catch (e) {
        // If we can't verify, still show the call
        try {
          await showFullScreenIncomingCall(
            callId: callId,
            callerId: callerId ?? '',
            callerName: callerName,
            callerPhoto: callerPhoto,
          );
        } catch (e) {
          print('[FCM] Error showing incoming call: $e');
        }
      }
    }
  } catch (e) {
    print('[FCM] Error processing message in background handler: $e');
  }
}

// Show full-screen incoming call UI - MUST be top-level (not private)
@pragma('vm:entry-point')
Future<void> showFullScreenIncomingCall({
  required String callId,
  required String callerId,
  required String callerName,
  String? callerPhoto,
}) async {
  try {
    // Use callId as CallKit id for consistency with notification_service.dart
    final callKitParams = CallKitParams(
      id: callId, // Use Firestore callId as CallKit id
      nameCaller: callerName,
      appName: 'Supper',
      avatar: callerPhoto,
      handle: 'Voice Call',
      type: 0, // 0 = Audio call
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

    // Update call status to 'ringing' so caller sees "Ringing..." (like WhatsApp)
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'ringing',
        'ringingAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Error updating status - non-fatal
    }
  } catch (e) {
    // Error showing CallKit UI - non-fatal, system will handle gracefully
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling for image decode errors
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    // Suppress image decode errors - they're non-fatal
    if (exception.toString().contains('ImageDecoder') ||
        exception.toString().contains('Failed to decode image') ||
        exception.toString().contains('codec')) {
      return; // Don't propagate
    }
    // For other errors, use default handler
    FlutterError.presentError(details);
  };

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Sentry for error tracking (wraps the entire app)
  await ErrorTrackingService.initialize(() async {
    // Initialize Firebase only once
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // CRITICAL: Register background message handler IMMEDIATELY after Firebase init
    // This must be done before runApp() for background notifications to work
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    if (!kIsWeb) {
      // Fixed: Changed from UNLIMITED to 50MB to prevent memory issues
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 50 * 1024 * 1024, // 50MB cache limit
      );
    }

    // Run app immediately - defer ALL heavy initializations
    runApp(const ProviderScope(child: MyApp()));

    // Defer all non-critical initialization to AFTER first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServicesInBackground();
    });
  });
}

/// Initialize non-critical services after app has started rendering
Future<void> _initializeServicesInBackground() async {
  // Shorter delay - reduced from 500ms to 200ms for faster startup
  await Future.delayed(const Duration(milliseconds: 200));

  // Initialize Firebase Analytics
  unawaited(AnalyticsService().initialize().catchError((e) {}));

  // Initialize utilities in sequence with small delays to prevent jank
  await AppOptimizer.initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  MemoryManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  UserManager().initialize();
  await Future.delayed(const Duration(milliseconds: 50));

  // Initialize notification service (can run in parallel, but don't block)
  unawaited(
    NotificationService().initialize().catchError((e) {
      ErrorTrackingService().captureException(
        e,
        message: 'NotificationService init failed',
      );
    }),
  );

  // Initialize connectivity service after a small delay
  await Future.delayed(const Duration(milliseconds: 100));
  unawaited(ConnectivityService().initialize().catchError((e) {}));

  // Log app open event
  unawaited(AnalyticsService().logAppOpen());

  // NOTE: Migrations are now run in AuthWrapper._initializeUserServices()
  // after the user is authenticated to avoid permission errors
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return MaterialApp(
      title: 'Supper',
      navigatorKey: navigatorKey,
      theme: themeNotifier.themeData.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0f0f23),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/voice-call') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => VoiceCallScreen(
              callId: args['callId'] as String,
              otherUser: args['otherUser'] as UserProfile,
              isOutgoing: args['isOutgoing'] as bool,
            ),
          );
        }
        return null;
      },
      builder: (context, child) {
        return Container(color: const Color(0xFF0f0f23), child: child);
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final ConversationService _conversationService = ConversationService();
  final NotificationService _notificationService = NotificationService();

  bool _hasInitializedServices = false;
  String? _lastInitializedUserId;
  bool _isInitializing = false;
  bool _isPerformingLogout = false; // Prevent multiple logout calls
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  StreamSubscription<dynamic>? _deviceSessionSubscription;
  Timer? _sessionCheckTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _isPerformingLogout = false;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _deviceSessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    _autoCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        if (_authService.currentUser != null) {
          _locationService.onAppResume();
        }
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Start real-time monitoring for device session changes (WhatsApp-style)
  /// Automatically logs out user if another device logs in with same account
  Future<void> _startDeviceSessionMonitoring(String userId) async {
    // Cancel any existing subscription
    _deviceSessionSubscription?.cancel();

    try {
      // Get local device token
      final localToken = await _authService.getLocalDeviceToken();
      if (localToken == null) {
        print('[DeviceSession] No local token found, skipping listener');
        return;
      }

      print('[DeviceSession] ✓ Starting real-time listener for user: $userId');

      // Listen to user document changes in real-time
      _deviceSessionSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots()
          .listen(
            (snapshot) async {
              if (!snapshot.exists) {
                print('[DeviceSession] User document deleted');
                if (mounted) {
                  await _performRemoteLogout(
                      'Account was deleted or access revoked');
                }
                return;
              }

              // Get the server data
              final forceLogout = snapshot.data()?['forceLogout'] as bool? ?? false;
              final serverToken = snapshot.data()?['activeDeviceToken'] as String?;

              print(
                  '[DeviceSession] 📡 Snapshot - forceLogout: $forceLogout, Local: ${localToken.substring(0, 8)}..., Server: ${serverToken?.substring(0, 8) ?? 'NULL'}...');

              // PRIORITY 1: Check forceLogout flag FIRST (instant logout signal - WhatsApp style!)
              // This check does NOT wait for debounce flag!
              if (forceLogout == true) {
                print('[DeviceSession] 🔴 FORCE LOGOUT SIGNAL DETECTED! Logging out IMMEDIATELY (WhatsApp-style)...');
                _isPerformingLogout = true; // Set immediately
                await _performRemoteLogout(
                    'Logged out: Account accessed on another device');
                return; // Don't check further conditions
              }

              // Prevent multiple logout calls for other checks
              if (_isPerformingLogout) {
                print('[DeviceSession] ⏳ Logout already in progress, skipping...');
                return;
              }

              // PRIORITY 2: Check if server token is null/empty (device logout signal)
              if (serverToken == null || serverToken.isEmpty) {
                print('[DeviceSession] ❌ TOKEN EMPTY/NULL! Another device logged in! Logging out...');
                if (mounted && !_isPerformingLogout) {
                  _isPerformingLogout = true;
                  await _performRemoteLogout(
                      'Logged out: Account accessed on another device');
                }
                return; // Don't check further conditions
              }

              // PRIORITY 3: If server token doesn't match our local token, another device logged in
              if (serverToken != localToken) {
                print(
                    '[DeviceSession] ❌ TOKEN MISMATCH DETECTED! Another device has this account! Logging out...');

                final deviceInfo = snapshot.data()?['deviceInfo'] as Map<String, dynamic>?;
                final deviceName = deviceInfo?['deviceName'] ?? 'Another Device';

                if (mounted && !_isPerformingLogout) {
                  _isPerformingLogout = true;
                  await _performRemoteLogout(
                      'Logged out: Account accessed on $deviceName');
                }
                return; // Don't check further conditions
              }

              // If we reach here, our token matches server token - we're the active device
              print('[DeviceSession] ✓ Token matches - we are the active device');
            },
            onError: (e) {
              print('[DeviceSession] ❌ Listener error: $e');
              // Reconnect on next resume if error occurs
            },
          );
    } catch (e) {
      print('[DeviceSession] Error starting listener: $e');
    }
  }

  /// Perform remote logout when another device logs in
  Future<void> _performRemoteLogout(String message) async {
    print('[RemoteLogout] ========== REMOTE LOGOUT INITIATED ==========');
    print('[RemoteLogout] Reason: $message');

    // Cancel subscriptions FIRST (before logout) so we don't listen to our own logout
    _deviceSessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    _autoCheckTimer?.cancel();
    print('[RemoteLogout] ✓ All subscriptions cancelled');

    // Force logout from Firebase IMMEDIATELY - this is critical!
    try {
      print('[RemoteLogout] 🔴 Starting signOut() - THIS WILL TRIGGER UI REFRESH!');

      // Sign out from Firebase
      await _authService.signOut();
      print('[RemoteLogout] ✓ Sign out completed');

      // Force rebuild by clearing initialization flags
      // This ensures the StreamBuilder immediately detects the null user state
      _hasInitializedServices = false;
      _lastInitializedUserId = null;
      _isInitializing = false;

      print('[RemoteLogout] 🔄 Auth state changed to null - StreamBuilder will now show login page');
    } catch (e) {
      print('[RemoteLogout] Error during signout: $e');
      // Try emergency logout
      try {
        print('[RemoteLogout] ⚠️ Attempting emergency signOut()...');
        await _authService.firebaseAuth.signOut();
        print('[RemoteLogout] ✓ Emergency sign out completed');

        // Also clear flags on emergency logout
        _hasInitializedServices = false;
        _lastInitializedUserId = null;
        _isInitializing = false;
      } catch (emergency_e) {
        print('[RemoteLogout] ❌ Emergency sign out also failed: $emergency_e');
      }
    }

    print('[RemoteLogout] ========== LOGOUT COMPLETE - LOGIN PAGE SHOWING NOW ==========');
  }

  @override
  Widget build(BuildContext context) {
    print('[BUILD] AuthWrapper.build() called');
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        print(
          '[BUILD] StreamBuilder fired - connectionState: ${snapshot.connectionState}',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[BUILD] Showing loading screen');
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          print('[BUILD] Has error: ${snapshot.error}');
          return _buildErrorScreen(snapshot.error.toString());
        }

        if (snapshot.hasData && snapshot.data != null) {
          print('[BUILD] User logged in: ${snapshot.data!.uid}');
          String uid = snapshot.data!.uid;

          // Start real-time device session monitoring (WhatsApp-style auto-logout)
          if (_lastInitializedUserId != uid) {
            _startDeviceSessionMonitoring(uid);
          }

          if (!_hasInitializedServices || _lastInitializedUserId != uid) {
            if (!_isInitializing) {
              _isInitializing = true;
              _hasInitializedServices = true;
              _lastInitializedUserId = uid;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initializeUserServices().then((_) {
                  _isInitializing = false;
                });
              });
            }
          }

          // CRITICAL: Wrap MainNavigationScreen with periodic validation
          // This ensures we ALWAYS check if session is still valid
          return _buildMainScreenWithValidation();
        }

        _hasInitializedServices = false;
        _lastInitializedUserId = null;
        _isInitializing = false;
        _isPerformingLogout = false; // Reset flag on logout

        return const OnboardingScreen();
      },
    );
  }

  /// Build main navigation screen
  Widget _buildMainScreenWithValidation() {
    return const MainNavigationScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeUserServices() async {
    print('[Init]   _initializeUserServices() CALLED  ');
    try {
      print('[Init] Starting user services initialization');

      // CRITICAL: Clean up any old subscriptions from previous login
      print('[Init] Cleaning up old device session subscriptions...');
      _deviceSessionSubscription?.cancel();
      _sessionCheckTimer?.cancel();
      _autoCheckTimer?.cancel();
      print('[Init] Old subscriptions cleaned');

      try {
        await _profileService.ensureProfileExists().timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
      } catch (e) {
        // Profile service error (non-fatal)
      }

      await Future.delayed(const Duration(milliseconds: 100));
      _locationService.initializeLocation();
      _locationService.startPeriodicLocationUpdates();
      _locationService.startLocationStream();
      _conversationService.cleanupDuplicateConversations();

      // Start listening for notifications from other users
      _startNotificationListener();
    } catch (e) {
      // User services init failed
    }
  }

  /// Listen for notifications from Firestore and show them locally
  void _startNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationService
        .getUserNotificationsStream()
        .listen(
          (notifications) async {
            try {
              for (final notification in notifications) {
                try {
                  await _notificationService.processNewNotification(
                    notification,
                  );
                } catch (e) {
                  // Error processing individual notification - continue to next
                }
              }
            } catch (e) {
              // Error processing notifications batch
            }
          },
          onError: (e) {
            // Stream error - will attempt to reconnect on next trigger
          },
        );
  }


}
