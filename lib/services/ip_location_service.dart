import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/location_services/geocoding_service.dart';

/// Ultra-fast location detection service.
/// Priority: Cache → Last Known GPS → Fresh GPS (3s) → IP fallback
/// Designed to return in <3 seconds in most cases.
class IpLocationService {
  IpLocationService._();

  // Cache last detected location for 5 minutes
  static Map<String, dynamic>? _cachedLocation;
  static DateTime? _cachedAt;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get location from IP address (city-level accuracy).
  /// Tries multiple IP geolocation APIs with race condition for speed.
  static Future<Map<String, dynamic>?> getIpLocation() async {
    // Race all 3 IP APIs — first success wins
    try {
      final result = await Future.any([
        _tryIpApi(),
        _tryIpInfo(),
        _tryIpWho(),
      ]).timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (result != null) return result;
    } catch (e) {
      debugPrint('IP location race error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _tryIpApi() async {
    final response = await http.get(
      Uri.parse('http://ip-api.com/json/?fields=status,lat,lon,city,regionName'),
    ).timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        final lat = (body['lat'] as num).toDouble();
        final lng = (body['lon'] as num).toDouble();
        final city = body['city'] as String? ?? '';
        final region = body['regionName'] as String? ?? '';
        debugPrint('📍 IP Location (ip-api): $city, $region ($lat, $lng)');
        return {'lat': lat, 'lng': lng, 'city': city, 'region': region};
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _tryIpInfo() async {
    final response = await http.get(
      Uri.parse('https://ipinfo.io/json'),
    ).timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final loc = (body['loc'] as String?)?.split(',');
      if (loc != null && loc.length == 2) {
        final lat = double.tryParse(loc[0]) ?? 0.0;
        final lng = double.tryParse(loc[1]) ?? 0.0;
        final city = body['city'] as String? ?? '';
        final region = body['region'] as String? ?? '';
        debugPrint('📍 IP Location (ipinfo): $city, $region ($lat, $lng)');
        return {'lat': lat, 'lng': lng, 'city': city, 'region': region};
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _tryIpWho() async {
    final response = await http.get(
      Uri.parse('https://ipwho.is/'),
    ).timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        final lat = (body['latitude'] as num).toDouble();
        final lng = (body['longitude'] as num).toDouble();
        final city = body['city'] as String? ?? '';
        final region = body['region'] as String? ?? '';
        debugPrint('📍 IP Location (ipwho): $city, $region ($lat, $lng)');
        return {'lat': lat, 'lng': lng, 'city': city, 'region': region};
      }
    }
    return null;
  }

  /// Ultra-fast location detection.
  /// Priority:
  ///   1. Memory cache (instant)
  ///   2. Last known GPS position (instant, no network)
  ///   3. Fresh GPS with 3s timeout (fast)
  ///   4. IP geolocation (parallel race, 3s)
  ///
  /// Returns {lat, lng, displayAddress} or null on total failure.
  /// Typical time: <1s (cached/lastKnown), 3s max (GPS), 4s max (IP fallback)
  static Future<Map<String, dynamic>?> detectLocation() async {
    // ── Step 0: Return cache if fresh ──
    if (_cachedLocation != null && _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheDuration) {
      debugPrint('📍 detectLocation: returning cached result');
      return _cachedLocation;
    }
    debugPrint('📍 detectLocation: starting fast detection...');

    // ── Step 1: Try last known position (INSTANT — no GPS poll) ──
    Position? gpsPosition;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (serviceOn) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }

        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          // Try last known position first — returns instantly
          try {
            final lastKnown = await Geolocator.getLastKnownPosition();
            if (lastKnown != null) {
              // Use if less than 30 minutes old
              final age = DateTime.now().difference(lastKnown.timestamp);
              if (age.inMinutes < 30) {
                gpsPosition = lastKnown;
                debugPrint('📍 Using last known GPS (${age.inMinutes}m old): ${lastKnown.latitude}, ${lastKnown.longitude}');
              }
            }
          } catch (e) {
            debugPrint('📍 Last known position error: $e');
          }

          // If no last known, get fresh GPS with SHORT timeout
          if (gpsPosition == null) {
            try {
              gpsPosition = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                  timeLimit: Duration(seconds: 3),
                ),
              );
              debugPrint('📍 Fresh GPS (3s): ${gpsPosition.latitude}, ${gpsPosition.longitude}');
            } catch (e) {
              debugPrint('📍 Fresh GPS failed (3s timeout): $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('📍 GPS overall error: $e');
    }

    // ── Step 2: Use GPS position if available ──
    if (gpsPosition != null) {
      // Reverse geocode in background — don't block on it
      String displayAddress = 'Lat ${gpsPosition.latitude.toStringAsFixed(4)}, Lng ${gpsPosition.longitude.toStringAsFixed(4)}';
      try {
        final address = await GeocodingService.getAddressFromCoordinates(
          gpsPosition.latitude, gpsPosition.longitude,
        ).timeout(const Duration(seconds: 3));
        final formatted = _formatAddress(address);
        if (formatted != null && formatted.isNotEmpty) {
          displayAddress = formatted;
        }
      } catch (e) {
        debugPrint('📍 Reverse geocode failed (non-blocking): $e');
      }
      final result = {
        'lat': gpsPosition.latitude,
        'lng': gpsPosition.longitude,
        'displayAddress': displayAddress,
      };
      _cachedLocation = result;
      _cachedAt = DateTime.now();
      return result;
    }

    // ── Step 3: IP geolocation (parallel race — fastest API wins) ──
    debugPrint('📍 GPS unavailable, racing IP APIs...');
    final ipResult = await getIpLocation();
    if (ipResult != null) {
      final lat = ipResult['lat'] as double;
      final lng = ipResult['lng'] as double;
      // Use IP city/region directly — skip reverse geocoding for speed
      String displayAddress = '${ipResult['city']}, ${ipResult['region']}';

      final result = {
        'lat': lat,
        'lng': lng,
        'displayAddress': displayAddress,
      };
      _cachedLocation = result;
      _cachedAt = DateTime.now();
      return result;
    }

    debugPrint('📍 All location methods failed');
    return null;
  }

  static String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return null;
    final city = address['city'] ?? '';
    final area = address['area'] ?? '';
    if (area.isNotEmpty && city.isNotEmpty && area != city) {
      return '$area, $city';
    } else if (city.isNotEmpty) {
      return city;
    } else if (area.isNotEmpty) {
      return area;
    }
    return null;
  }
}
