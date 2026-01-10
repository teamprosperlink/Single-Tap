import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../connectivity_service.dart';
import '../../res/config/app_assets.dart';

class GeocodingService {
  // Using OpenStreetMap's Nominatim API (free, no API key required)
  static const String nominatimUrl = AppAssets.osmReverseGeocode;

  // Alternative: Using Google's Geocoding API (requires API key)
  static const String googleGeocodingUrl = AppAssets.googleMapsGeocode;

  // For production, you should use your own API key
  static const String googleApiKey =
      'YOUR_GOOGLE_MAPS_API_KEY'; // Replace with actual key

  /// Get detailed address from coordinates using multiple services
  static Future<Map<String, dynamic>?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint('GeocodingService: Getting address for $latitude, $longitude');

      // Check connectivity first
      final connectivityService = ConnectivityService();
      if (!connectivityService.hasConnection) {
        debugPrint('GeocodingService: No internet connection, cannot geocode');
        return null; // Cannot get address without internet
      }

      // For web, try multiple geocoding services
      if (kIsWeb) {
        // Try BigDataCloud API first (no CORS issues, free)
        final bigDataResult = await _getBigDataCloudAddress(
          latitude,
          longitude,
        );
        if (bigDataResult != null) {
          return bigDataResult;
        }

        // Try OpenCage as fallback
        final openCageResult = await _getOpenCageAddress(latitude, longitude);
        if (openCageResult != null) {
          return openCageResult;
        }

        // REMOVED: IP-based location fallback (shows wrong location)
        // Only use real GPS coordinates, not IP-based guessing

        // Return null if all real geocoding services fail
        return null;
      }

      // For mobile platforms, try Nominatim
      final nominatimResult = await _getNominatimAddress(latitude, longitude);
      if (nominatimResult != null) {
        return nominatimResult;
      }

      // Return null if geocoding fails - don't show fake "Location detected"
      // The caller should handle this by requesting permission or showing error
      return null;
    } catch (e) {
      debugPrint('GeocodingService: Error getting address: $e');
      // Return null on error - no fake locations
      return null;
    }
  }

  /// Get default location data when services fail
  // ignore: unused_element
  static Map<String, dynamic> _getDefaultLocation(
    double latitude,
    double longitude,
  ) {
    return {
      'formatted': 'Location detected',
      'area': '',
      'city': 'Location detected',
      'state': '',
      'pincode': '',
      'country': '',
      'latitude': latitude,
      'longitude': longitude,
      'display': 'Location detected',
    };
  }

  /// Get address using OpenStreetMap Nominatim API
  static Future<Map<String, dynamic>?> _getNominatimAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$nominatimUrl?lat=$latitude&lon=$longitude&format=json&addressdetails=1',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Supper App/1.0', // Required by Nominatim
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('GeocodingService: Nominatim response: $data');

        final address = data['address'] ?? {};

        // Extract detailed location components
        String area = '';
        String city = '';
        String state = '';
        String pincode = '';
        String country = '';

        // Get area (most specific locality)
        area =
            address['suburb'] ??
            address['neighbourhood'] ??
            address['hamlet'] ??
            address['locality'] ??
            address['road'] ??
            '';

        // Get city
        city =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            address['district'] ??
            '';

        // Get state
        state = address['state'] ?? address['state_district'] ?? '';

        // Get pincode
        pincode = address['postcode'] ?? '';

        // Get country
        country = address['country'] ?? '';

        // Build formatted address like e-commerce apps
        String formattedAddress = '';

        if (area.isNotEmpty) {
          formattedAddress = area;
        }

        if (city.isNotEmpty && city != area) {
          if (formattedAddress.isNotEmpty) {
            formattedAddress += ', $city';
          } else {
            formattedAddress = city;
          }
        }

        if (pincode.isNotEmpty) {
          formattedAddress += ' - $pincode';
        }

        if (state.isNotEmpty && !formattedAddress.contains(state)) {
          formattedAddress += ', $state';
        }

        // Create detailed location object
        return {
          'formatted': formattedAddress,
          'area': area,
          'city': city,
          'state': state,
          'pincode': pincode,
          'country': country,
          'latitude': latitude,
          'longitude': longitude,
          'display': _createDisplayAddress(area, city, state, pincode),
        };
      }

      return null;
    } catch (e) {
      debugPrint('GeocodingService: Nominatim error: $e');
      return null;
    }
  }

  /// Create display address like Swiggy/Flipkart
  static String _createDisplayAddress(
    String area,
    String city,
    String state,
    String pincode,
  ) {
    String display = '';

    // Priority: Area name if available
    if (area.isNotEmpty) {
      display = area;
      if (city.isNotEmpty && city != area) {
        display += ', $city';
      }
    } else if (city.isNotEmpty) {
      display = city;
    }

    // Add pincode if available
    if (pincode.isNotEmpty && display.isNotEmpty) {
      display += ' $pincode';
    }

    // If still empty, use state
    if (display.isEmpty && state.isNotEmpty) {
      display = state;
    }

    return display.isNotEmpty ? display : 'Location detected';
  }

  /// Get address using BigDataCloud API (works well with web, no CORS)
  static Future<Map<String, dynamic>?> _getBigDataCloudAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '${AppAssets.bigDataCloudGeocode}'
        '?latitude=$latitude&longitude=$longitude&localityLanguage=en',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('GeocodingService: BigDataCloud response: $data');

        // Extract location details
        String area = data['locality'] ?? '';
        String city = data['city'] ?? data['locality'] ?? '';
        String state = data['principalSubdivision'] ?? '';
        String pincode = data['postcode'] ?? '';
        String country = data['countryName'] ?? '';

        // Get more specific area from localityInfo
        if (data['localityInfo'] != null) {
          final localityInfo = data['localityInfo'];
          if (localityInfo['administrative'] != null &&
              localityInfo['administrative'].isNotEmpty) {
            final admins = localityInfo['administrative'] as List;
            // Get the most specific administrative area
            for (var admin in admins) {
              if (admin['order'] == 6 || admin['order'] == 5) {
                area = admin['name'] ?? area;
                break;
              }
            }
          }
        }

        // Build formatted address
        String formattedAddress = '';
        if (area.isNotEmpty) {
          formattedAddress = area;
        }
        if (city.isNotEmpty && city != area) {
          formattedAddress += formattedAddress.isEmpty ? city : ', $city';
        }
        if (pincode.isNotEmpty) {
          formattedAddress += ' $pincode';
        }

        return {
          'formatted': formattedAddress,
          'area': area,
          'city': city,
          'state': state,
          'pincode': pincode,
          'country': country,
          'latitude': latitude,
          'longitude': longitude,
          'display': formattedAddress.isNotEmpty
              ? formattedAddress
              : 'Location detected',
        };
      }

      return null;
    } catch (e) {
      debugPrint('GeocodingService: BigDataCloud error: $e');
      return null;
    }
  }

  /// Get address using OpenCage API (requires free API key)
  static Future<Map<String, dynamic>?> _getOpenCageAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      // You can get a free API key from https://opencagedata.com/
      const apiKey = 'YOUR_OPENCAGE_API_KEY'; // Replace with actual key

      if (apiKey == 'YOUR_OPENCAGE_API_KEY') {
        return null; // Skip if no API key
      }

      final url = Uri.parse(
        '${AppAssets.openCageGeocode}'
        '?q=$latitude+$longitude&key=$apiKey&language=en&pretty=1',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final components = result['components'] ?? {};

          return {
            'formatted': result['formatted'] ?? '',
            'area': components['suburb'] ?? components['neighbourhood'] ?? '',
            'city': components['city'] ?? components['town'] ?? '',
            'state': components['state'] ?? '',
            'pincode': components['postcode'] ?? '',
            'country': components['country'] ?? '',
            'latitude': latitude,
            'longitude': longitude,
            'display':
                result['formatted']?.split(',').take(2).join(',') ??
                'Location detected',
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('GeocodingService: OpenCage error: $e');
      return null;
    }
  }

  /// Fallback: Get approximate location using IP address (for web)
  // ignore: unused_element
  static Future<Map<String, dynamic>?> _getIPBasedLocation() async {
    try {
      // Using ipapi.co (free, works with HTTPS)
      final url = Uri.parse(AppAssets.ipApiGeocode);
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return {
          'formatted': '${data['city']}, ${data['region']}',
          'area': data['city'] ?? '',
          'city': data['city'] ?? '',
          'state': data['region'] ?? '',
          'pincode': data['postal'] ?? '',
          'country': data['country_name'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'display': '${data['city'] ?? 'Location'}, ${data['region'] ?? ''}',
        };
      }

      return null;
    } catch (e) {
      debugPrint('GeocodingService: IP location error: $e');
      return null;
    }
  }

  /// Search for location by text query (for search functionality)
  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    try {
      final url = Uri.parse(
        '${AppAssets.osmSearch}'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=5',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Supper App/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        return results.map((result) {
          final address = result['address'] ?? {};

          return {
            'formatted': result['display_name'] ?? '',
            'area': address['suburb'] ?? address['neighbourhood'] ?? '',
            'city': address['city'] ?? address['town'] ?? '',
            'state': address['state'] ?? '',
            'pincode': address['postcode'] ?? '',
            'country': address['country'] ?? '',
            'latitude': double.tryParse(result['lat'] ?? '0') ?? 0.0,
            'longitude': double.tryParse(result['lon'] ?? '0') ?? 0.0,
            'display':
                result['display_name']?.split(',').take(3).join(',') ?? '',
          };
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('GeocodingService: Search error: $e');
      return [];
    }
  }
}
