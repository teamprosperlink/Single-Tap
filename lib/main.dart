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
import 'package:shared_preferences/shared_preferences.dart';
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
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;
  StreamSubscription<dynamic>? _deviceSessionSubscription;
  Timer? _sessionCheckTimer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
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
          // Validate device session when app resumes
          _validateDeviceOnResume();
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

  /// Validate device session when app resumes from background
  Future<void> _validateDeviceOnResume() async {
    // Validate session, but handle logout manually to show message
    final isValid = await _authService.validateDeviceSession(autoLogout: false);
    if (!isValid && mounted) {
      await _performRemoteLogout();
    }
  }

  /// Direct logout detection - starts IMMEDIATELY when user logs in
  void _startDirectLogoutDetection(String userId) {
    // ignore: avoid_print
    print(
      '[DirectDetection] ✓ Starting direct logout detection for user: $userId',
    );

    // Cancel any existing timers
    _autoCheckTimer?.cancel();

    // Check very FREQUENTLY - every 100ms
    // This is the MAIN logout detection mechanism
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      try {
        final isValid = await _authService.validateDeviceSession(
          autoLogout: true,
        );

        // Debug log every 10th check (once per second) to avoid spam
        if (timer.tick % 10 == 0) {
          // ignore: avoid_print
          print('[DirectDetection] ✓ Tick ${timer.tick}: Session valid = $isValid');
        }

        if (!isValid) {
          // ignore: avoid_print
          print('[DirectDetection] ❌ SESSION INVALID - LOGOUT TRIGGERED!');
          // ignore: avoid_print
          print('[DirectDetection] Cancelling all timers and subscriptions');
          timer.cancel();
          _sessionCheckTimer?.cancel();
          _deviceSessionSubscription?.cancel();
          _autoCheckTimer?.cancel();

          // CRITICAL: Call _performRemoteLogout to show snackbar and redirect to login
          // ignore: avoid_print
          print('[DirectDetection] ✓ Calling _performRemoteLogout()');
          if (mounted) {
            await _performRemoteLogout();
          } else {
            // ignore: avoid_print
            print('[DirectDetection] ⚠️ Widget not mounted, skipping logout UI');
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[DirectDetection] ⚠️ Error during validation: $e');
        // Don't cancel timer on error, keep checking
      }
    });

    // ignore: avoid_print
    print(
      '[DirectDetection] ✓ Direct detection timer started (100ms interval)',
    );
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

          // START LOGOUT DETECTION IMMEDIATELY - called from StreamBuilder
          print('[BUILD]   STARTING LOGOUT DETECTION NOW');
          _startDirectLogoutDetection(uid);

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

        return const OnboardingScreen();
      },
    );
  }

  /// Wraps MainNavigationScreen with periodic session validation
  Widget _buildMainScreenWithValidation() {
    print('[MainScreen] BUILD CALLED - checking timer...');

    // Start validation timer if not already running
    if (_autoCheckTimer == null || !_autoCheckTimer!.isActive) {
      print('[MainScreen]   STARTING session validation timer (500ms)');
      _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) async {
        print('[Validation]  Checking session...');

        if (!mounted) {
          print('[Validation] Widget not mounted, cancelling');
          timer.cancel();
          return;
        }

        try {
          final isValid = await _authService.validateDeviceSession(
            autoLogout: true,
          );
          print('[Validation] Session valid=$isValid');

          if (!isValid) {
            print('[Validation] SESSION INVALID - LOGGING OUT!  ');
            timer.cancel();
            _sessionCheckTimer?.cancel();
            _deviceSessionSubscription?.cancel();
          }
        } catch (e) {
          print('[Validation]  Error: $e');
        }
      });
    } else {
      print('[MainScreen] Timer already running');
    }

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

      // Validate device session - check if user logged in from another device
      // Silently logout if invalid - no message shown
      final isValidDevice = await _authService.validateDeviceSession();
      print('[Init] Device session validation result: $isValidDevice');
      if (!isValidDevice) {
        print('[Init] Device session invalid, returning early');
        return;
      }

      // Start aggressive session validation - check every 200ms while app is open
      // This will catch ANY logout attempt from other devices
      print('[Init]  Starting AGGRESSIVE session validation every 200ms...');
      _autoCheckTimer?.cancel();
      int checkCount = 0;
      _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) async {
        checkCount++;
        if (checkCount % 10 == 0) {
          // Log every 10 checks (every 2 seconds)
          print(
            '[AggressiveCheck]  Check #$checkCount - validating session...',
          );
        }

        if (!mounted) {
          timer.cancel();
          return;
        }

        final isValid = await _authService.validateDeviceSession(
          autoLogout: true,
        );
        if (!isValid) {
          print('[AggressiveCheck]  SESSION INVALID - LOGOUT TRIGGERED!  ');
          timer.cancel();
          _sessionCheckTimer?.cancel();
          _deviceSessionSubscription?.cancel();
        }
      });

      // Start real-time device session listener for instant remote logout
      // This MUST complete setup before continuing
      // Moved up to ensure session is monitored immediately
      print('[Init] Starting device session listener...');
      await _startDeviceSessionListener();
      print('[Init] Device session listener started successfully');

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

      // Start automatic session validation check every 1 second
      // This is a simple backup to ensure logout happens
      _startAutoSessionCheck();
    } catch (e) {
      // User services init failed
    }
  }

  /// Automatic session check - simple backup to ensure logout works
  void _startAutoSessionCheck() {
    // Cancel any existing auto check timer first
    _autoCheckTimer?.cancel();

    // Simple timer that checks session validity every 300ms (faster backup)
    _autoCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        // Simple validateDeviceSession call
        final isValid = await _authService.validateDeviceSession(
          autoLogout: true,
        );
        if (!isValid && mounted) {
          print('[AutoCheck] Session invalid - logging out');
          timer.cancel();
          _sessionCheckTimer?.cancel();
          _deviceSessionSubscription?.cancel();
          await _authService.forceLogout();
        }
      } catch (e) {
        // Continue checking
      }
    });
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

  /// Listen for device session changes in real-time
  /// Instantly logout user when they're logged out from another device
  Future<void> _startDeviceSessionListener() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      // ignore: avoid_print
      print('[DeviceSession]  No user ID, skipping listener setup');
      return;
    }

    // Get local token FIRST before setting up stream
    final localToken = await _authService.getLocalDeviceToken();
    print(
      '[DeviceSession] Retrieved local token: ${localToken?.substring(0, 6) ?? 'NULL'}...',
    );
    if (localToken == null || localToken.isEmpty) {
      // ignore: avoid_print
      print('[DeviceSession]  No local token found, skipping listener setup');
      return;
    }

    // Verify token was saved to Firestore by checking current value
    final currentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final firestoreToken = currentDoc.data()?['activeDeviceToken'] as String?;
    print(
      '[DeviceSession] Current Firestore token: ${firestoreToken?.substring(0, 6) ?? 'NULL'}...',
    );
    print(
      '[DeviceSession] Local and Firestore match: ${localToken == firestoreToken}',
    );

    // ignore: avoid_print
    print(
      '[DeviceSession] ✓ Setting up listener for user: $userId with token: ${localToken.substring(0, 6)}...',
    );

    // IMPORTANT: Don't cancel polling timer here - we need BOTH polling AND stream
    // Stream might not fire on slow networks, so polling catches it
    _deviceSessionSubscription?.cancel();

    // Only cancel old polling if it exists AND is running
    if (_sessionCheckTimer != null && _sessionCheckTimer!.isActive) {
      print('[DeviceSession] Cancelling old polling timer');
      _sessionCheckTimer!.cancel();
    }

    // Start ULTRA-AGGRESSIVE polling - check every 150ms for real device compatibility
    // Real devices often have slower network, so check more frequently
    print(
      '[DeviceSession] ✓ Starting polling timer (150ms interval for real device)',
    );
    _sessionCheckTimer = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) {
      if (!mounted) {
        print('[Poll] Widget not mounted, cancelling timer');
        timer.cancel();
        return;
      }

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        print('[Poll] No current user, cancelling timer');
        timer.cancel();
        return;
      }

      // CRITICAL: Read fresh local token EVERY TIME
      // Don't use cached token - it could be stale
      _authService
          .getLocalDeviceToken()
          .then((freshToken) {
            if (freshToken != null) {
              // print('[Poll]   Fresh token from SharedPrefs: ${freshToken.substring(0, 6)}...');  // Too verbose
              _checkDeviceSessionSync(currentUser.uid, freshToken);
            } else {
              print(
                '[Poll]   Local token is NULL - user might have been logged out',
              );
              timer.cancel();
            }
          })
          .catchError((e) {
            print('[Poll]  ERROR getting local token: $e');
          });
    });

    // ALSO listen to Firestore stream for INSTANT detection of token changes
    // This is MUCH more reliable than polling
    print('[Stream] Starting real-time Firestore listener for user: $userId with local token: ${localToken.substring(0, 6)}...');
    _deviceSessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              // Log every snapshot received
              print('[Stream] 📡 Snapshot received - exists: ${snapshot.exists}');

              if (!snapshot.exists) {
                print('[Stream] ❌ User document deleted!');
                _performRemoteLogout();
                return;
              }

              final data = snapshot.data();
              final serverToken = data?['activeDeviceToken'] as String?;

              // Get fresh local token in case it changed
              final currentLocalToken = await _authService.getLocalDeviceToken();

              print(
                '[Stream] 📡 Firestore update - server token: ${serverToken?.substring(0, 6) ?? 'NULL'}..., local: ${currentLocalToken?.substring(0, 6) ?? 'NULL'}...',
              );

              // Token deleted or changed - logout immediately
              if (serverToken == null ||
                  serverToken.isEmpty ||
                  (currentLocalToken != null && serverToken != currentLocalToken)) {
                print(
                  '[Stream] ❌ TOKEN MISMATCH/DELETED - LOGOUT IMMEDIATELY!',
                );
                print('[Stream]   Server: ${serverToken?.substring(0, 6) ?? 'NULL'}');
                print('[Stream]   Local: ${currentLocalToken?.substring(0, 6) ?? 'NULL'}');

                _sessionCheckTimer?.cancel();
                _deviceSessionSubscription?.cancel();
                _autoCheckTimer?.cancel();

                if (mounted) {
                  print('[Stream] Calling _performRemoteLogout()');
                  await _performRemoteLogout();
                } else {
                  print('[Stream] ⚠️ Widget not mounted, cannot logout');
                }
              }
            } catch (e) {
              print('[Stream] ❌ Error: $e');
            }
          },
          onError: (e) {
            print('[Stream] ❌ Stream error: $e');
          },
        );

    print('[DeviceSession] Polling + Stream setup complete');
  }

  /// Synchronously check device session without async overhead
  /// This is called every 250ms to ensure logout detection
  void _checkDeviceSessionSync(String userId, String localToken) {
    // Use async operation but don't await in the timer
    print(
      '[Poll]   POLLING - Checking UID: $userId with token: ${localToken.substring(0, 6)}...',
    );
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server))
        .then((userDoc) {
          if (!mounted) {
            print('[Poll] Widget not mounted, skipping check');
            return;
          }

          final serverToken = userDoc.data()?['activeDeviceToken'] as String?;
          print(
            '[Poll]   GOT FIRESTORE DATA - local=${localToken.substring(0, 6)}... server=${serverToken?.substring(0, 6) ?? 'NULL'}',
          );

          // Check if token was deleted or mismatched (remote logout detected)
          if (serverToken == null ||
              serverToken.isEmpty ||
              serverToken != localToken) {
            print('[Poll] *** LOGOUT DETECTED ***');
            print(
              '[Poll] Server token: ${serverToken?.substring(0, 6) ?? 'NULL'}...',
            );
            print('[Poll] Local token: ${localToken.substring(0, 6)}...');
            print('[Poll] Match: ${serverToken == localToken}');
            print('[Poll] Calling _performRemoteLogout()');

            // CRITICAL: Cancel timers IMMEDIATELY to prevent double-calls
            _sessionCheckTimer?.cancel();
            _deviceSessionSubscription?.cancel();
            _autoCheckTimer?.cancel();

            if (mounted) {
              print('[Poll] Proceeding with remote logout...');
              // Important: await the logout so it fully completes
              unawaited(_performRemoteLogout());
            } else {
              print('[Poll] Widget not mounted, cannot proceed with logout');
            }
          }
        })
        .catchError((e) {
          print('[Poll]  Error checking device session: $e');
          // Continue polling even on error
        });
  }

  /// Perform remote logout - cancel subscriptions and force logout
  Future<void> _performRemoteLogout() async {
    // ignore: avoid_print
    print('[Logout] ========== REMOTE LOGOUT INITIATED ==========');

    // Cancel all subscriptions first
    _deviceSessionSubscription?.cancel();
    _sessionCheckTimer?.cancel();
    _autoCheckTimer?.cancel();
    print('[Logout] ✓ Cancelled all timers and subscriptions');

    // CRITICAL: Clear local device token FIRST
    print('[Logout] Clearing local device token from SharedPreferences...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_login_token');
      print('[Logout] ✓ Local device token cleared');
    } catch (e) {
      print('[Logout] ⚠️ Error clearing token: $e');
    }

    // Show logout message - wrap in try-catch so it doesn't block logout
    if (mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Logged out: Account accessed on another device',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 8),
            dismissDirection: DismissDirection.none,
          ),
        );
        // ignore: avoid_print
        print('[Logout] ✓ SNACKBAR SHOWN - USER CAN SEE NOTIFICATION');
      } catch (e) {
        // ignore: avoid_print
        print('[Logout] ⚠️ Snackbar error (non-blocking): $e');
      }
    }

    // Force logout from Firebase - this triggers StreamBuilder to rebuild
    // ignore: avoid_print
    print('[Logout] Step 1: Calling forceLogout()');
    try {
      await _authService.forceLogout();
      // ignore: avoid_print
      print('[Logout] ✓ Step 1: forceLogout() succeeded');
    } catch (e) {
      // ignore: avoid_print
      print(
        '[Logout] ⚠️ Step 1: forceLogout() failed: $e - attempting direct signout',
      );
      try {
        await _authService.firebaseAuth.signOut();
        // ignore: avoid_print
        print('[Logout] ✓ Step 1: Direct signout succeeded');
      } catch (e2) {
        // ignore: avoid_print
        print('[Logout] ❌ Step 1: Direct signout also failed: $e2');
      }
    }

    // Wait for Firebase state to propagate
    await Future.delayed(const Duration(milliseconds: 200));

    // Verify logout worked
    final currentUser = _authService.currentUser;
    // ignore: avoid_print
    print(
      '[Logout] Step 2: Verification - current user: ${currentUser?.uid ?? 'NULL (GOOD!)'}',
    );

    if (currentUser != null) {
      // ignore: avoid_print
      print('[Logout] ⚠️ Step 2: User still logged in! Attempting force signout...');
      try {
        await _authService.firebaseAuth.signOut();
        // ignore: avoid_print
        print('[Logout] ✓ Step 2: Force signout completed');
        await Future.delayed(const Duration(milliseconds: 100));
        final userAfterForce = _authService.currentUser;
        // ignore: avoid_print
        print(
          '[Logout] Step 2: After force signout - user: ${userAfterForce?.uid ?? 'NULL (GOOD!)'}',
        );
      } catch (e) {
        // ignore: avoid_print
        print('[Logout] ❌ Step 2: Force signout failed: $e');
      }
    }

    // ignore: avoid_print
    print('[Logout] ========== LOGOUT PROCESS COMPLETE ==========');
    // ignore: avoid_print
    print('[Logout] ✓ StreamBuilder<User?> should now detect state change');
    // ignore: avoid_print
    print('[Logout] ✓ LoginScreen should appear in 1-2 seconds');
  }
}
