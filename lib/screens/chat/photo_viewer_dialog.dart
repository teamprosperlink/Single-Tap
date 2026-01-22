import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../res/config/app_colors.dart';

class PhotoViewerDialog extends StatefulWidget {
  final String imageUrl;
  final String title;

  const PhotoViewerDialog({
    super.key,
    required this.imageUrl,
    this.title = 'Photo',
  });

  static Future<void> show(BuildContext context, String imageUrl, {String? title}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => PhotoViewerDialog(
        imageUrl: imageUrl,
        title: title ?? 'Photo',
      ),
    );
  }

  @override
  State<PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<PhotoViewerDialog> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    final uri = Uri.parse(widget.imageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A2B3D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.download_rounded,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: _downloadImage,
                        tooltip: 'Download',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Image with pinch to zoom
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white70 : AppColors.iosBlue,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading image',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Zoom controls
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Colors.grey),
                    onPressed: () {
                      final currentScale = _transformationController.value.getMaxScaleOnAxis();
                      if (currentScale > 0.5) {
                        _transformationController.value = Matrix4.identity()
                          ..scale(currentScale - 0.5);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Reset Zoom'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Colors.grey),
                    onPressed: () {
                      final currentScale = _transformationController.value.getMaxScaleOnAxis();
                      if (currentScale < 4.0) {
                        _transformationController.value = Matrix4.identity()
                          ..scale(currentScale + 0.5);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
