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

  //    EXTERNAL SERVICE ICONS
  static const String googleAuthIcon =
      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg';

  //    DEMO VIDEO URLs
  static const String demoBeeVideo =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
  static const String demoButterflyVideo =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  // Demo reels video list
  static const List<String> demoReelVideos = [
    demoBeeVideo,
    demoButterflyVideo,
    demoBeeVideo,
    demoButterflyVideo,
    demoBeeVideo,
    demoButterflyVideo,
    demoBeeVideo,
    demoButterflyVideo,
  ];

  //    DEMO FOOD/MARKETPLACE IMAGES (Unsplash)

  // User Profile Placeholder
  static const String demoUserAvatar =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100';

  // Food Images
  static const String imgButterChicken =
      'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400';
  static const String imgPaneerTikka =
      'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400';
  static const String imgBiryani =
      'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400';
  static const String imgMasalaDosa =
      'https://images.unsplash.com/photo-1630383249896-424e482df921?w=400';
  static const String imgPizza =
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400';
  static const String imgPasta =
      'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400';
  static const String imgBurger =
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400';
  static const String imgTacos =
      'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=400';
  static const String imgSushi =
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=400';
  static const String imgRamen =
      'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=400';
  static const String imgFriedRice =
      'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400';
  static const String imgNoodles =
      'https://images.unsplash.com/photo-1552611052-33e04de081de?w=400';
  static const String imgSalad =
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400';
  static const String imgSoup =
      'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=400';
  static const String imgSteak =
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=400';
  static const String imgSeafood =
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=400';
  static const String imgDessert =
      'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=400';
  static const String imgIceCream =
      'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=400';
  static const String imgCake =
      'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400';
  static const String imgCoffee =
      'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400';
  static const String imgTea =
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400';
  static const String imgJuice =
      'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400';
  static const String imgSmoothie =
      'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=400';
  static const String imgCocktail =
      'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=400';
  static const String imgWine =
      'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=400';
  static const String imgBeer =
      'https://images.unsplash.com/photo-1535958636474-b021ee887b13?w=400';

  // Restaurant Images
  static const String imgRestaurant1 =
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400';
  static const String imgRestaurant2 =
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=400';
  static const String imgRestaurant3 =
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400';
  static const String imgRestaurant4 =
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=400';
  static const String imgCafe1 =
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=400';
  static const String imgCafe2 =
      'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=400';
  static const String imgBakery =
      'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400';
  static const String imgStreetFood =
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400';

  // Cuisine Type Images
  static const String imgIndianCuisine =
      'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400';
  static const String imgChineseCuisine =
      'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=400';
  static const String imgItalianCuisine =
      'https://images.unsplash.com/photo-1498579150354-977475b7ea0b?w=400';
  static const String imgMexicanCuisine =
      'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400';
  static const String imgJapaneseCuisine =
      'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?w=400';
  static const String imgThaiCuisine =
      'https://images.unsplash.com/photo-1562565652-a0d8f0c59eb4?w=400';
  static const String imgAmericanCuisine =
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400';
  static const String imgMediterranean =
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=400';

  //    PLACEHOLDER IMAGES
  static const String placeholderUser =
      'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=200';
  static const String placeholderFood =
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400';
  static const String placeholderRestaurant =
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400';

  //    POST PLACEHOLDER IMAGES
  static const List<String> demoPostImages = [
    'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600', // Watch
    'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=600', // Headphones
    'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=600', // Camera
    'https://images.unsplash.com/photo-1560343090-f0409e92791a?w=600', // Shoes
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600', // Nike Shoe
    'https://images.unsplash.com/photo-1585386959984-a4155224a1ad?w=600', // Perfume
    'https://images.unsplash.com/photo-1600185365926-3a2ce3cdb9eb?w=600', // Bag
    'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600', // Phone
    'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=600', // Laptop
    'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=600', // Tablet
  ];

  /// Get a random demo post image
  static String getRandomPostImage(int index) {
    return demoPostImages[index % demoPostImages.length];
  }

  //    API ENDPOINTS
  static const String geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com';
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

  //    APP LINKS
  static const String appDownloadLink = 'https://supper.app/download';

  //    HELPER METHODS

  /// Get Unsplash image URL with custom width
  static String unsplashImage(String photoId, {int width = 400}) {
    return 'https://images.unsplash.com/photo-$photoId?w=$width';
  }

  /// Get Unsplash image URL with custom width and height
  static String unsplashImageSized(
    String photoId, {
    int width = 400,
    int height = 400,
  }) {
    return 'https://images.unsplash.com/photo-$photoId?w=$width&h=$height&fit=crop';
  }
}
