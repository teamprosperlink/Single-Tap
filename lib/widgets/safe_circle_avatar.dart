import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../res/utils/photo_url_helper.dart';

/// A CircleAvatar that safely handles network images with proper error handling.
/// Shows user's initial letter when image fails to load or is not available.
class SafeCircleAvatar extends StatefulWidget {
  final String? photoUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final List<Color>? gradientColors;

  const SafeCircleAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.radius = 24,
    this.backgroundColor,
    this.gradientColors,
  });

  @override
  State<SafeCircleAvatar> createState() => _SafeCircleAvatarState();
}

class _SafeCircleAvatarState extends State<SafeCircleAvatar> {
  bool _hasError = false;

  @override
  void didUpdateWidget(SafeCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state if URL changes
    if (oldWidget.photoUrl != widget.photoUrl) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = PhotoUrlHelper.fixGooglePhotoUrl(widget.photoUrl);
    final initial = (widget.name?.isNotEmpty == true) ? widget.name![0].toUpperCase() : '?';
    final colors = widget.gradientColors ?? _getDefaultGradient(widget.name ?? '');
    final bgColor = widget.backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1);

    // Build fallback widget with initial
    Widget buildInitialWidget() {
      if (widget.gradientColors != null) {
        return Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: widget.radius * 0.9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: widget.radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    }

    // If no valid URL or has error, show initial
    if (fixedUrl == null || fixedUrl.isEmpty || _hasError) {
      return buildInitialWidget();
    }

    // For web platform, use Image.network with error handling
    if (kIsWeb) {
      return ClipOval(
        child: Image.network(
          fixedUrl,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Set error state to prevent repeated attempts
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasError) {
                setState(() => _hasError = true);
              }
            });
            PhotoUrlHelper.markAsFailed(fixedUrl);
            return buildInitialWidget();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return buildInitialWidget();
          },
        ),
      );
    }

    // For mobile platforms, use CachedNetworkImage
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: fixedUrl,
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => buildInitialWidget(),
        errorWidget: (context, url, error) {
          // Mark as rate-limited if 429 error
          if (error.toString().contains('429')) {
            PhotoUrlHelper.markAsRateLimited(url);
          }
          PhotoUrlHelper.markAsFailed(url);
          return buildInitialWidget();
        },
      ),
    );
  }

  List<Color> _getDefaultGradient(String name) {
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFFf093fb), const Color(0xFFf5576c)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
      [const Color(0xFF30cfd0), const Color(0xFF330867)],
      [const Color(0xFFa8edea), const Color(0xFFfed6e3)],
      [const Color(0xFF5ee7df), const Color(0xFFb490ca)],
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % gradients.length;
    return gradients[index];
  }
}
