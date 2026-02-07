import 'dart:io';

/// Stub service for business media management.
class BusinessMediaService {
  // Singleton pattern
  static final BusinessMediaService _instance =
      BusinessMediaService._internal();
  factory BusinessMediaService() => _instance;
  BusinessMediaService._internal();

  /// Get gallery images for a business.
  Future<List<String>> getGalleryImages(String businessId) async {
    return [];
  }

  /// Upload a media file to the specified folder.
  Future<String?> uploadMedia(dynamic file, String folder) async {
    return null;
  }

  /// Upload a cover image for a business.
  Future<String?> uploadCoverImage(File imageFile) async {
    return null;
  }
}
