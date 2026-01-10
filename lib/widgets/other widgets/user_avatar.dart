import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/config/app_text_styles.dart';

class UserAvatar extends StatelessWidget {
  final String? profileImageUrl;
  final double radius;
  final String? fallbackText;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.profileImageUrl,
    this.radius = 20,
    this.fallbackText,
    this.backgroundColor,
  });

  String? _fixPhotoUrl(String? url) {
    // Use the centralized helper with rate limiting protection
    return PhotoUrlHelper.fixGooglePhotoUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = _fixPhotoUrl(profileImageUrl);

    final bgColor = backgroundColor ?? Colors.grey.shade300;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: fixedUrl != null
            ? CachedNetworkImage(
                imageUrl: fixedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                // Add longer cache duration with higher resolution
                cacheKey: fixedUrl,
                maxWidthDiskCache:
                    1024, // Increased from 400 for better quality
                maxHeightDiskCache:
                    1024, // Increased from 400 for better quality
                memCacheWidth: (radius * 4)
                    .round(), // Doubled for sharper images
                memCacheHeight: (radius * 4)
                    .round(), // Doubled for sharper images
                placeholder: (context, url) => Container(
                  color: bgColor,
                  child: Icon(
                    Icons.person,
                    size: radius,
                    color: Colors.grey.shade600,
                  ),
                ),
                errorWidget: (context, url, error) {
                  // Mark URL as rate-limited if it's a 429 error
                  if (error.toString().contains('429') &&
                      url.contains('googleusercontent.com')) {
                    PhotoUrlHelper.markAsRateLimited(url);
                  }
                  // Use fallback silently
                  return Container(
                    color: bgColor,
                    child: Center(
                      child: Text(
                        fallbackText?.isNotEmpty == true
                            ? fallbackText![0].toUpperCase()
                            : '?',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: radius * 0.8,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: bgColor,
                child: Center(
                  child: fallbackText?.isNotEmpty == true
                      ? Text(
                          fallbackText![0].toUpperCase(),
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: radius * 0.8,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: radius,
                          color: Colors.grey.shade600,
                        ),
                ),
              ),
      ),
    );
  }
}
