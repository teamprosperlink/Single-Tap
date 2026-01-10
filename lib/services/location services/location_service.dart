import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'geocoding_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Debouncing: Prevent multiple simultaneous location updates
  bool _isUpdatingLocation = false;
  DateTime? _lastLocationUpdate;
  bool _periodicUpdatesStarted =
      false; // Prevent multiple periodic update loops
  bool _isInitialized = false; // Prevent multiple initialization calls
  bool _isFetchingBackground = false; // Prevent duplicate background fetches

  // Timer for periodic updates (cancellable)
  Timer? _periodicTimer;

  // Stream subscription for location updates
  StreamSubscription<Position>? _positionStreamSubscription;

  // Last known position for distance filtering
  Position? _lastKnownPosition;

  // Location freshness: Consider location stale after 24 hours
  static const Duration locationFreshnessThreshold = Duration(hours: 24);

  // Minimum distance (meters) user must move before updating location
  static const double minimumDistanceForUpdate = 100.0; // 100 meters

  // Enable/disable verbose logging (set to false for production)
  static const bool _enableVerboseLogging = false;

  void _log(String message) {
    if (_enableVerboseLogging) {
      debugPrint(message);
    }
  }

  // Check if permission has been requested before
  Future<bool> hasRequestedPermissionBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_permission_requested') ?? false;
  }

  // Mark that permission has been requested
  Future<void> markPermissionRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_permission_requested', true);
  }

  // Get current location SILENTLY in background (no user prompts)
  // highAccuracy: if true, uses HIGH accuracy (slower but precise)
  Future<Position?> getCurrentLocation({
    bool silent = true,
    bool highAccuracy = false,
  }) async {
    try {
      _log(
        'LocationService: Starting getCurrentLocation (silent=$silent, highAccuracy=$highAccuracy), isWeb=$kIsWeb',
      );

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _log('LocationService: Services enabled=$serviceEnabled');

      if (!serviceEnabled) {
        _log('Location services are disabled - fetching silently failed');
        // Don't show any alerts, just return null silently
        if (!kIsWeb) {
          return null;
        }
      }

      // Check permission status SILENTLY
      LocationPermission permission = await Geolocator.checkPermission();
      _log('LocationService: Current permission=$permission');

      // If permission not granted and this is a silent background fetch
      if (silent && permission == LocationPermission.denied) {
        _log('LocationService: Permission not granted, skipping silent fetch');
        // Don't request permission during silent background fetch
        return null;
      }

      // Only request permission if NOT silent mode (user initiated)
      if (!silent && permission == LocationPermission.denied) {
        final hasRequested = await hasRequestedPermissionBefore();
        _log('LocationService: Has requested before=$hasRequested');

        if (!hasRequested || kIsWeb) {
          // Always try on web
          // Request permission for the first time
          _log('LocationService: Requesting permission...');
          permission = await Geolocator.requestPermission();
          _log('LocationService: New permission=$permission');
          await markPermissionRequested();
        } else {
          _log('Permission denied previously');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _log(
          'Location permissions are permanently denied - silent fetch skipped',
        );
        return null;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // HIGH ACCURACY MODE: User wants precise location
        if (highAccuracy) {
          _log(
            'LocationService: Using HIGH accuracy mode (may take longer)...',
          );
          try {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.best,
                timeLimit: Duration(seconds: 60),
              ),
            );
            _log(
              'LocationService: Got HIGH accuracy position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m',
            );
            return position;
          } catch (e) {
            _log(
              'LocationService: High accuracy failed: $e, falling back to medium...',
            );
            // Fall through to medium accuracy
          }
        }

        // BALANCED MODE: Try for good accuracy without taking too long
        _log('LocationService: Getting position with balanced strategy...');

        // For user-initiated requests (not silent), skip last known position
        // to ensure we get fresh data
        if (silent) {
          // Strategy 1: Try last known position FIRST (instant, no GPS wait)
          // ONLY for background silent updates
          try {
            _log('LocationService: Trying last known position first...');
            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              _log(
                'LocationService: Got last known position lat=${lastPosition.latitude}, lng=${lastPosition.longitude}',
              );
              // Continue fetching fresh location in background, but return this immediately
              _fetchFreshLocationInBackground();
              return lastPosition;
            }
          } catch (e) {
            _log('LocationService: Last known position failed: $e');
          }
        }

        // Strategy 2: Try HIGH accuracy first for user-initiated requests
        if (!silent) {
          try {
            _log(
              'LocationService: Trying high accuracy with 45s timeout (user-initiated)...',
            );
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 45),
              ),
            );
            _log(
              'LocationService: Got high accuracy position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m',
            );
            return position;
          } catch (e) {
            _log('LocationService: High accuracy failed: $e, trying medium...');
          }
        }

        // Strategy 3: Try medium accuracy with moderate timeout (balanced)
        try {
          _log('LocationService: Trying medium accuracy with 30s timeout...');
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 30),
            ),
          );
          _log(
            'LocationService: Got medium accuracy position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m',
          );
          return position;
        } catch (e) {
          _log('LocationService: Medium accuracy failed: $e');
        }

        // Strategy 4: Try low accuracy as fallback (works even with weak GPS)
        try {
          _log('LocationService: Trying low accuracy with 20s timeout...');
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            ),
          );
          _log(
            'LocationService: Got low accuracy position lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m',
          );
          return position;
        } catch (e) {
          _log('LocationService: Low accuracy failed: $e');
        }
      }

      return null;
    } catch (e) {
      _log('LocationService: Error getting location: $e');
      // On web, try a simpler approach
      if (kIsWeb) {
        try {
          _log('LocationService: Trying web fallback...');
          final position = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: highAccuracy
                  ? LocationAccuracy.best
                  : LocationAccuracy.medium,
            ),
          );
          _log(
            'LocationService: Web fallback success lat=${position.latitude}, lng=${position.longitude}',
          );
          return position;
        } catch (webError) {
          _log('LocationService: Web fallback failed: $webError');
        }
      }
      return null;
    }
  }

  // Fetch fresh location in background without blocking
  void _fetchFreshLocationInBackground() async {
    // Prevent duplicate background fetches
    if (_isFetchingBackground) {
      _log(
        'LocationService: Background fetch already in progress, skipping...',
      );
      return;
    }

    _isFetchingBackground = true;

    try {
      _log('LocationService: Fetching fresh location in background...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 60),
        ),
      );
      _log(
        'LocationService: Background fetch completed lat=${position.latitude}, lng=${position.longitude}',
      );

      // Update user location silently in background
      // Note: updateUserLocation has its own rate limiting
      await updateUserLocation(position: position);
    } catch (e) {
      _log('LocationService: Background fetch failed (not critical): $e');
      // Silently fail - don't show errors to user
    } finally {
      _isFetchingBackground = false;
    }
  }

  // Get city name from coordinates - Enhanced with real API
  Future<Map<String, dynamic>?> getCityFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      _log(
        'LocationService: Getting detailed address for lat=$latitude, lng=$longitude',
      );

      // Use the new geocoding service for all platforms
      final addressData = await GeocodingService.getAddressFromCoordinates(
        latitude,
        longitude,
      );

      if (addressData != null) {
        _log('LocationService: Got address data: ${addressData['display']}');
        return addressData;
      }

      // Fallback to old geocoding method if API fails
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            latitude,
            longitude,
          );

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];

            return {
              'formatted':
                  '${place.locality ?? place.subLocality ?? ''}, ${place.administrativeArea ?? ''}',
              'area': place.subLocality ?? '',
              'city': place.locality ?? '',
              'state': place.administrativeArea ?? '',
              'pincode': place.postalCode ?? '',
              'country': place.country ?? '',
              'display': place.locality ?? '',
            };
          }
        } catch (e) {
          _log('LocationService: Fallback geocoding failed: $e');
        }
      }

      // If all geocoding fails, return null - don't fake location
      _log('LocationService: Could not reverse geocode coordinates');
      return null;
    } catch (e) {
      _log('LocationService: Error getting address: $e');
      return null;
    }
  }

  // Calculate distance between two positions in meters
  double _calculateDistance(Position pos1, Position pos2) {
    return Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
  }

  // Update user's location in Firestore with detailed address - SILENT MODE SUPPORTED
  Future<bool> updateUserLocation({
    Position? position,
    bool silent = true,
    bool forceUpdate = false,
  }) async {
    try {
      _log(
        'LocationService: updateUserLocation called (silent=$silent, forceUpdate=$forceUpdate)',
      );

      // DEBOUNCE: If already updating, skip this call
      if (_isUpdatingLocation) {
        _log(
          'LocationService: Already updating location, skipping duplicate call',
        );
        return false;
      }

      // RATE LIMIT: Don't update more than once per minute (unless forced)
      if (!forceUpdate && _lastLocationUpdate != null) {
        final timeSinceLastUpdate = DateTime.now().difference(
          _lastLocationUpdate!,
        );
        if (timeSinceLastUpdate.inSeconds < 60) {
          _log(
            'LocationService: Updated ${timeSinceLastUpdate.inSeconds}s ago, skipping (rate limit: 60s)',
          );
          return false;
        }
      }

      _isUpdatingLocation = true;

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('LocationService: No authenticated user');
        _isUpdatingLocation = false;
        return false;
      }

      Position? currentPosition =
          position ?? await getCurrentLocation(silent: silent);

      // DISTANCE CHECK: Skip update if user hasn't moved significantly (unless forced)
      if (!forceUpdate &&
          currentPosition != null &&
          _lastKnownPosition != null) {
        final distance = _calculateDistance(
          _lastKnownPosition!,
          currentPosition,
        );
        if (distance < minimumDistanceForUpdate) {
          _log(
            'LocationService: User moved only ${distance.toStringAsFixed(1)}m (< ${minimumDistanceForUpdate}m), skipping update',
          );
          _isUpdatingLocation = false;
          _lastLocationUpdate =
              DateTime.now(); // Still update timestamp to prevent rapid checks
          return true; // Return true since location is still valid
        }
        _log(
          'LocationService: User moved ${distance.toStringAsFixed(1)}m, updating location',
        );
      }

      if (currentPosition != null) {
        // Get detailed address from coordinates SILENTLY
        final addressData = await getCityFromCoordinates(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        if (addressData != null &&
            addressData['city'] != null &&
            addressData['city'].toString().isNotEmpty) {
          _log(
            'LocationService: Updating user location silently with detailed address: ${addressData['display']}',
          );

          Map<String, dynamic> locationData = {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
            'location':
                addressData['formatted'] ??
                addressData['display'] ??
                addressData['city'],
            'city': addressData['city'],
            'area': addressData['area'] ?? '',
            'state': addressData['state'] ?? '',
            'pincode': addressData['pincode'] ?? '',
            'country': addressData['country'] ?? '',
            'displayLocation': addressData['display'] ?? addressData['city'],
            'locationUpdatedAt': FieldValue.serverTimestamp(),
          };

          // Update user document SILENTLY in background - use set with merge to ensure document exists
          await _firestore
              .collection('users')
              .doc(userId)
              .set(locationData, SetOptions(merge: true));

          _log(
            'LocationService: Location updated silently with area: ${addressData['area']}, city: ${addressData['city']}',
          );
          _lastKnownPosition = currentPosition; // Save for distance filtering
          _lastLocationUpdate = DateTime.now();
          _isUpdatingLocation = false;
          return true;
        } else {
          _log(
            'LocationService: Could not get valid address data from coordinates (silent fetch)',
          );
          _isUpdatingLocation = false;
          return false;
        }
      } else {
        _log('LocationService: Could not get current position (silent fetch)');
        _isUpdatingLocation = false;
        return false;
      }
    } catch (e) {
      _log('LocationService: Error updating user location: $e');
      _isUpdatingLocation = false;
      // Fail silently - no user-facing errors or fake locations
      return false;
    }
  }

  // Initialize location on app start - SILENT BACKGROUND PROCESS
  Future<void> initializeLocation() async {
    // Prevent multiple initialization calls
    if (_isInitialized) {
      _log('LocationService: Already initialized, skipping...');
      return;
    }

    _isInitialized = true;

    try {
      _log('LocationService: Initializing location silently in background...');

      // Check if location services are enabled SILENTLY
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        _log(
          'LocationService: Location services are disabled - skipping silent init',
        );
        return; // Exit silently, no alerts
      }

      // Check if we have permission already SILENTLY
      LocationPermission permission = await Geolocator.checkPermission();
      _log('LocationService: Current permission: $permission');

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // We have permission, update location SILENTLY in background
        _log('LocationService: Have permission, fetching location silently...');
        final success = await updateUserLocation(silent: true);
        _log('LocationService: Silent location update success: $success');
      } else if (permission == LocationPermission.denied) {
        // Check if this is the VERY FIRST TIME (app just installed)
        final hasRequested = await hasRequestedPermissionBefore();

        if (!hasRequested) {
          // ONLY on very first app launch, request permission once
          _log(
            'LocationService: First app launch - requesting location permission ONE TIME...',
          );
          permission = await Geolocator.requestPermission();
          await markPermissionRequested();
          _log('LocationService: Permission after request: $permission');

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            _log(
              'LocationService: Permission granted, updating location silently...',
            );
            final success = await updateUserLocation(silent: true);
            _log('LocationService: Silent location update success: $success');
          } else {
            _log(
              'LocationService: Permission denied by user - will not ask again',
            );
          }
        } else {
          // Permission was already requested before, skip silently
          _log(
            'LocationService: Permission was requested before, skipping silent init',
          );
        }
      } else if (permission == LocationPermission.deniedForever) {
        _log(
          'LocationService: Permission denied forever - skipping silent init',
        );
      }
    } catch (e) {
      _log('LocationService: Error initializing location: $e');
      // Fail silently - no user-facing errors
    }
  }

  // Request location permission manually (USER INITIATED - for settings)
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      await markPermissionRequested();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Permission granted, update location (NOT SILENT - user requested)
        return await updateUserLocation(silent: false);
      }

      return false;
    } catch (e) {
      _log('Error requesting location permission: $e');
      return false;
    }
  }

  // Open app settings for location permission
  Future<void> openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  // Clear stored permission preference (for testing)
  Future<void> clearPermissionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_permission_requested');
  }

  // Start periodic background location updates (SILENT)
  Future<void> startPeriodicLocationUpdates() async {
    try {
      // CRITICAL: Only start once to prevent multiple timers
      if (_periodicUpdatesStarted) {
        _log('LocationService: Periodic updates already running, skipping...');
        return;
      }

      _periodicUpdatesStarted = true;
      _log(
        'LocationService: Starting periodic background location updates (every 10 minutes)...',
      );

      // Cancel any existing timer first
      _periodicTimer?.cancel();

      // Use Timer.periodic instead of while(true) - can be cancelled on logout
      _periodicTimer = Timer.periodic(const Duration(minutes: 10), (
        timer,
      ) async {
        try {
          // Check if user is still authenticated
          if (_auth.currentUser != null) {
            _log('LocationService: Running periodic silent location update...');
            await updateUserLocation(silent: true);
          } else {
            _log(
              'LocationService: User not authenticated, stopping periodic updates',
            );
            stopPeriodicLocationUpdates();
          }
        } catch (e) {
          _log('LocationService: Error in periodic update: $e');
          // Continue timer even if one update fails
        }
      });

      // Do first update immediately (don't wait 10 minutes)
      _log('LocationService: Running initial location update...');
      Future.delayed(const Duration(seconds: 2), () async {
        if (_auth.currentUser != null) {
          await updateUserLocation(silent: true);
        }
      });
    } catch (e) {
      _log('LocationService: Error starting periodic updates: $e');
    }
  }

  // Stop periodic location updates (call on logout)
  void stopPeriodicLocationUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _periodicUpdatesStarted = false;
    _log('LocationService: Periodic updates stopped');
  }

  /// Start listening to location stream for efficient background updates
  /// This is more battery-efficient than Timer.periodic as it only triggers
  /// when the device actually moves
  Future<void> startLocationStream() async {
    try {
      // Check permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _log('LocationService: No permission for location stream');
        return;
      }

      // Cancel existing subscription
      _positionStreamSubscription?.cancel();

      _log(
        'LocationService: Starting location stream (distance filter: ${minimumDistanceForUpdate}m)...',
      );

      // Use location stream with distance filter - only triggers when user moves
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium, // Battery efficient
        distanceFilter: minimumDistanceForUpdate
            .toInt(), // Only update when moved 100+ meters
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) async {
              _log(
                'LocationService: Stream received new position lat=${position.latitude}, lng=${position.longitude}',
              );

              // Check if user is still authenticated
              if (_auth.currentUser != null) {
                // Update location (forceUpdate since stream already filtered by distance)
                await updateUserLocation(
                  position: position,
                  silent: true,
                  forceUpdate: true,
                );
              }
            },
            onError: (error) {
              _log('LocationService: Stream error: $error');
            },
          );
    } catch (e) {
      _log('LocationService: Error starting location stream: $e');
    }
  }

  // Update location when app comes to foreground (SILENT)
  Future<void> onAppResume() async {
    try {
      _log('LocationService: App resumed, checking location freshness...');
      await checkAndRefreshStaleLocation();
    } catch (e) {
      _log('LocationService: Error updating location on resume: $e');
    }
  }

  // Check if location is stale and refresh if needed (SMART FRESHNESS CHECK)
  Future<bool> checkAndRefreshStaleLocation() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('LocationService: No authenticated user');
        return false;
      }

      // Get user's current location data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final locationUpdatedAt = data?['locationUpdatedAt'] as Timestamp?;

        if (locationUpdatedAt != null) {
          final lastUpdate = locationUpdatedAt.toDate();
          final timeSinceUpdate = DateTime.now().difference(lastUpdate);

          _log(
            'LocationService: Last location update was ${timeSinceUpdate.inHours} hours ago',
          );

          // If location is older than 24 hours, refresh it
          if (timeSinceUpdate > locationFreshnessThreshold) {
            _log(
              'LocationService: Location is stale (>${locationFreshnessThreshold.inHours}h old), refreshing...',
            );
            return await updateUserLocation(silent: true);
          } else {
            _log(
              'LocationService: Location is fresh (${timeSinceUpdate.inHours}h old), no update needed',
            );
            return true;
          }
        } else {
          // No location timestamp, update location
          _log(
            'LocationService: No location timestamp found, updating location...',
          );
          return await updateUserLocation(silent: true);
        }
      } else {
        // User document doesn't exist, create with location
        _log(
          'LocationService: User document not found, creating with location...',
        );
        return await updateUserLocation(silent: true);
      }
    } catch (e) {
      _log('LocationService: Error checking location freshness: $e');
      return false;
    }
  }

  // Get location age in hours for UI display
  Future<int?> getLocationAgeInHours() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final locationUpdatedAt = data?['locationUpdatedAt'] as Timestamp?;

        if (locationUpdatedAt != null) {
          final lastUpdate = locationUpdatedAt.toDate();
          final timeSinceUpdate = DateTime.now().difference(lastUpdate);
          return timeSinceUpdate.inHours;
        }
      }
      return null;
    } catch (e) {
      _log('LocationService: Error getting location age: $e');
      return null;
    }
  }

  // Check location status and return user-friendly error message
  Future<Map<String, dynamic>> checkLocationStatus() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        return {
          'canGetLocation': false,
          'reason': 'Location services are disabled',
          'message': 'Please enable location/GPS in your device settings',
          'canOpenSettings': true,
        };
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        return {
          'canGetLocation': false,
          'reason': 'Permission denied forever',
          'message':
              'Please enable location permission for this app in your device settings',
          'canOpenSettings': true,
        };
      }

      if (permission == LocationPermission.denied) {
        return {
          'canGetLocation': false,
          'reason': 'Permission not granted',
          'message': 'Location permission is required to find matches near you',
          'canRequestPermission': true,
        };
      }

      return {
        'canGetLocation': true,
        'reason': 'All good',
        'message': 'Location is available',
      };
    } catch (e) {
      return {
        'canGetLocation': false,
        'reason': 'Error checking location',
        'message': 'Failed to check location status: $e',
      };
    }
  }

  // Force refresh location - SILENT background process (user can call manually from settings)
  Future<bool> forceRefreshLocation({
    bool silent = true,
    bool highAccuracy = false,
  }) async {
    try {
      _log(
        'LocationService: Force refreshing location (silent=$silent, highAccuracy=$highAccuracy)...',
      );
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('LocationService: No authenticated user');
        return false;
      }

      // Check if location services are enabled SILENTLY
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && !kIsWeb) {
        _log(
          'LocationService: Location services are disabled - skipping silent refresh',
        );
        return false;
      }

      // Check permission silently
      LocationPermission permission = await Geolocator.checkPermission();

      // Only request permission if user-initiated (not silent)
      if (!silent && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        await markPermissionRequested();
      }

      if (permission == LocationPermission.deniedForever) {
        _log(
          'LocationService: Permission denied forever - skipping silent refresh',
        );
        return false;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get fresh location with specified accuracy
        final position = await getCurrentLocation(
          silent: silent,
          highAccuracy: highAccuracy,
        );
        if (position != null) {
          _log(
            'LocationService: Got GPS position: ${position.latitude}, ${position.longitude}, accuracy=${position.accuracy}m',
          );

          // Update user location SILENTLY
          return await updateUserLocation(position: position, silent: silent);
        } else {
          _log('LocationService: Could not get GPS position (silent fetch)');
          return false;
        }
      }

      return false;
    } catch (e) {
      _log('LocationService: Error force refreshing location: $e');
      // Fail silently
      return false;
    }
  }

  // Get current location accuracy (in meters)
  Future<double?> getCurrentLocationAccuracy() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position?.accuracy;
    } catch (e) {
      _log('LocationService: Error getting location accuracy: $e');
      return null;
    }
  }

  // Get location permission status
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Reset service state (call on logout)
  void reset() {
    stopPeriodicLocationUpdates();
    _isInitialized = false;
    _lastLocationUpdate = null;
    _lastKnownPosition = null;
    _isUpdatingLocation = false;
    _isFetchingBackground = false;
    _log('LocationService: State reset');
  }
}
