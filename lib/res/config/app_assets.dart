/// Centralized asset URLs and paths for the entire app
/// Use these static constants instead of hardcoding URLs in widgets
class AppAssets {
  AppAssets._(); // Private constructor to prevent instantiation

  //    LOCAL ASSET PATHS
  static const String logoPath = 'assets/logo/Clogo.jpeg';
  static const String searchRequirementImage =
      'assets/logo/searchRequirementData.jpeg';
  static const String searchAnnounceImage =
      'assets/logo/searchannaunceData.jpeg';
  static const String searchDataImage = 'assets/logo/searchData.jpeg';
  static const String homeBackgroundImage = 'assets/logo/home_background.webp';

  //    AUDIO ASSET PATHS
  /// Ringtone for incoming calls (used with audioplayers AssetSource)
  static const String ringtoneAudio = 'audio/ringtone.mp3';

  /// Calling tone for outgoing calls (used with audioplayers AssetSource)
  static const String callingToneAudio = 'audio/calling_tone.mp3';

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
  static const String ipApiGeocode = 'https://ipapi.co/json/';
}
