/// Centralized asset URLs and paths for the entire app
/// Use these static constants instead of hardcoding URLs in widgets
class AppAssets {
  AppAssets._(); // Private constructor to prevent instantiation

  //    LOCAL ASSET PATHS
  static const String logoPath = 'assets/logo/SingleTap.png';
  static const String searchRequirementImage =
      'assets/logo/searchRequirementData.jpeg';
  static const String searchAnnounceImage =
      'assets/logo/searchannaunceData.jpeg';
  static const String searchDataImage = 'assets/logo/searchData.jpeg';
  static const String homeBackgroundImage = 'assets/logo/home_background.webp';

  //    PRODUCT API
  static const String productApiBaseUrl = 'https://singletap-backend.onrender.com';
  static const String productApiUrl = '$productApiBaseUrl/search-and-match';
  static const String createPostUrl = '$productApiBaseUrl/create-post';
  static const String nearbyFeedUrl = '$productApiBaseUrl/nearby/feed';
  static const String nearbyForMeUrl = '$productApiBaseUrl/nearby/for-me';
  static const String storeListingUrl = '$productApiBaseUrl/store-listing';

  //    API ENDPOINTS
  static const String osmReverseGeocode =
      'https://nominatim.openstreetmap.org/reverse';
  static const String osmSearch = 'https://nominatim.openstreetmap.org/search';
  static const String googleMapsGeocode =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const String bigDataCloudGeocode =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';
  static const String openCageGeocode =
      'https://api.opencagedata.com/geocode/v1/json';
}
