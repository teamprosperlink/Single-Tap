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
  StreamSubscription<User?>? _authStateSubscription;
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
    _authStateSubscription?.cancel();
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
      print('[DeviceSession] Local device token: ${localToken.substring(0, 8)}...');

      // Listen to user document changes in real-time
      // Use server source first to get fresh data
      _deviceSessionSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(includeMetadataChanges: false)
          .listen(
            (snapshot) async {
              print('[DeviceSession] 📡 SNAPSHOT RECEIVED - exists: ${snapshot.exists}');

              if (!snapshot.exists) {
                print('[DeviceSession] User document deleted');
                if (mounted && !_isPerformingLogout) {
                  _isPerformingLogout = true;
                  await _performRemoteLogout(
                      'Account was deleted or access revoked');
                }
                return;
              }

              // Get the server data
              final snapshotData = snapshot.data();
              final forceLogout = snapshotData?['forceLogout'] as bool? ?? false;
              final serverToken = snapshotData?['activeDeviceToken'] as String?;

              print('[DeviceSession] 📡 Data: forceLogout=$forceLogout, serverToken=${serverToken?.substring(0, 8) ?? "NULL"}..., localToken=${localToken.substring(0, 8)}...');
              print('[DeviceSession] 📡 _isPerformingLogout=$_isPerformingLogout, mounted=$mounted');

              // Already performing logout - skip this snapshot
              if (_isPerformingLogout) {
                print('[DeviceSession] ⏳ Already performing logout, skipping...');
                return;
              }

              // PRIORITY 1: Check forceLogout flag FIRST (instant logout signal - WhatsApp style!)
              if (forceLogout == true) {
                print('[DeviceSession] 🔴 FORCE LOGOUT DETECTED! forceLogout=true');
                print('[DeviceSession] 🔴 About to set _isPerformingLogout=true and call _performRemoteLogout()');
                _isPerformingLogout = true;
                await _performRemoteLogout(
                    'Logged out: Account accessed on another device');
                print('[DeviceSession] 🔴 _performRemoteLogout() completed');
                return;
              }

              // PRIORITY 2: Check if server token is null/empty (another device logged in)
              if ((serverToken == null || serverToken.isEmpty) && localToken.isNotEmpty) {
                print('[DeviceSession] ❌ TOKEN EMPTY DETECTED!');
                _isPerformingLogout = true;
                await _performRemoteLogout(
                    'Logged out: Account accessed on another device');
                return;
              }

              // PRIORITY 3: Token mismatch - another device is active
              if (serverToken != null &&
                  serverToken.isNotEmpty &&
                  serverToken != localToken) {
                print('[DeviceSession] ❌ TOKEN MISMATCH! Other device is active');
                _isPerformingLogout = true;
                await _performRemoteLogout(
                    'Logged out: Account accessed on another device');
                return;
              }

              // Token matches - we're still the active device
              print('[DeviceSession] ✓ Session check OK - token matches');
            },
            onError: (e) {
              print('[DeviceSession] ❌ Listener error: $e');
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
    print('[RemoteLogout] Current user BEFORE logout: ${_authService.currentUser?.uid ?? "null"}');
    print('[RemoteLogout] Widget mounted? $mounted');

    try {
      // Cancel subscriptions FIRST (before logout)
      print('[RemoteLogout] Cancelling subscriptions...');
      _deviceSessionSubscription?.cancel();
      _sessionCheckTimer?.cancel();
      _autoCheckTimer?.cancel();
      _authStateSubscription?.cancel(); // Also cancel auth subscription
      print('[RemoteLogout] ✓ All subscriptions cancelled');

      // Clear flags BEFORE logout
      print('[RemoteLogout] Clearing state flags...');
      _hasInitializedServices = false;
      _lastInitializedUserId = null;
      _isInitializing = false;
      // NOTE: Keep _isPerformingLogout = true until the end

      // Sign out from Firebase
      print('[RemoteLogout] 🔴 Calling signOut()...');
      await _authService.signOut();
      print('[RemoteLogout] ✓ Firebase sign out completed');

      // CRITICAL: Wait for Firebase to process logout
      print('[RemoteLogout] ⏳ Waiting for Firebase auth state to clear...');

      // Wait with multiple checks
      int waitCount = 0;
      while (_authService.currentUser != null && waitCount < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        print('[RemoteLogout] ⏳ Wait iteration $waitCount - currentUser still: ${_authService.currentUser?.uid ?? "null"}');
        waitCount++;
      }

      final stillLoggedIn = _authService.currentUser != null;
      print('[RemoteLogout] ✓ After ${waitCount * 100}ms - still logged in? $stillLoggedIn');

      // Final check - ensure we're actually logged out
      if (_authService.currentUser != null) {
        print('[RemoteLogout] ⚠️ WARNING: currentUser is still not null after wait, forcing immediate signOut...');
        await _authService.firebaseAuth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
        print('[RemoteLogout] ✓ Force sign out completed');
      }

      // Now trigger rebuild - this will cause StreamBuilder to rebuild and show login
      if (mounted) {
        print('[RemoteLogout] 🔄 Widget is mounted - triggering setState to rebuild...');
        setState(() {
          print('[RemoteLogout] setState callback executing');
          // This causes build() to be called
          // build() will check currentUser and show OnboardingScreen if null
        });

        // Give Flutter a chance to process the rebuild
        await Future.delayed(const Duration(milliseconds: 100));
        print('[RemoteLogout] ✓ setState completed and Flutter processing done');
      } else {
        print('[RemoteLogout] ⚠️ Widget is NOT mounted - cannot rebuild UI');
      }

      _isPerformingLogout = false; // Reset at the very end
      print('[RemoteLogout] ✓ Remote logout completed successfully');
    } catch (e) {
      print('[RemoteLogout] ❌ Error in logout: $e');
      _isPerformingLogout = false;

      // Force logout anyway
      try {
        print('[RemoteLogout] 🚨 FORCE LOGOUT via firebaseAuth...');
        await _authService.firebaseAuth.signOut();

        _hasInitializedServices = false;
        _lastInitializedUserId = null;

        if (mounted) {
          setState(() {});
          print('[RemoteLogout] ✓ Emergency rebuild done');
        }
      } catch (e2) {
        print('[RemoteLogout] ❌ Emergency logout failed: $e2');
      }
    }

    print('[RemoteLogout] ========== END OF LOGOUT FUNCTION ==========');
  }

  @override
  Widget build(BuildContext context) {
    print('[BUILD] >>>>>>>>>> AuthWrapper.build() called');

    // CRITICAL CHECK FIRST - before even building StreamBuilder
    final currentUser = _authService.currentUser;
    print('[BUILD] CRITICAL FIRST CHECK - currentUser: ${currentUser?.uid ?? "null"}');

    if (currentUser == null) {
      print('[BUILD] ✓✓✓ currentUser is NULL - IMMEDIATELY showing login screen (before StreamBuilder)');
      _hasInitializedServices = false;
      _lastInitializedUserId = null;
      _isInitializing = false;
      _isPerformingLogout = false;
      return const OnboardingScreen();
    }

    print('[BUILD] currentUser exists: ${currentUser.uid} - proceeding with StreamBuilder');

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        print(
          '[BUILD] StreamBuilder fired - connectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data: ${snapshot.data?.uid ?? "null"}',
        );

        // CRITICAL: Always check currentUser directly again in case snapshot is stale or delayed
        final currentUserAgain = _authService.currentUser;
        print('[BUILD] Direct auth check AGAIN - currentUser: ${currentUserAgain?.uid ?? "null"}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[BUILD] connectionState is waiting - checking if we should show login instead...');
          // Even if waiting, if currentUser is null, show login
          if (currentUserAgain == null) {
            print('[BUILD] ✓ During WAITING state, currentUser is null - show login screen');
            return const OnboardingScreen();
          }
          print('[BUILD] Showing loading screen');
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          print('[BUILD] Has error: ${snapshot.error}');
          return _buildErrorScreen(snapshot.error.toString());
        }

        // CRITICAL FIX: If currentUser is null, ALWAYS show login regardless of snapshot state
        if (currentUserAgain == null) {
          print('[BUILD] ✓✓ currentUser is null in StreamBuilder builder - showing login screen');
          _hasInitializedServices = false;
          _lastInitializedUserId = null;
          _isInitializing = false;
          _isPerformingLogout = false;
          return const OnboardingScreen();
        }

        // Use snapshot data only if currentUser is not null
        final userFromSnapshot = snapshot.data;

        if (userFromSnapshot != null) {
          print('[BUILD] User logged in: ${userFromSnapshot.uid}');
          String uid = userFromSnapshot.uid;

          // Start real-time device session monitoring (WhatsApp-style auto-logout)
          if (_lastInitializedUserId != uid) {
            print('[BUILD] Starting device session monitoring for new user: $uid');
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
          print('[BUILD] Showing MainNavigationScreen');
          return _buildMainScreenWithValidation();
        }

        // User is logged out - show login screen
        _hasInitializedServices = false;
        _lastInitializedUserId = null;
        _isInitializing = false;
        _isPerformingLogout = false; // Reset flag on logout

        print('[BUILD] No user in snapshot - showing OnboardingScreen');
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
