import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable photo upload grid component
class PhotoUploadGrid extends StatelessWidget {
  final List<String> existingUrls;
  final List<File> newFiles;
  final int maxImages;
  final Function(List<String> urls, List<File> files) onImagesChanged;

  const PhotoUploadGrid({
    super.key,
    required this.existingUrls,
    required this.newFiles,
    this.maxImages = 5,
    required this.onImagesChanged,
  });

  Future<void> _pickImage(BuildContext context) async {
    final totalImages = existingUrls.length + newFiles.length;
    if (totalImages >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $maxImages images allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      final updatedFiles = [...newFiles, File(image.path)];
      onImagesChanged(existingUrls, updatedFiles);
    }
  }

  void _removeExistingImage(int index) {
    final updatedUrls = [...existingUrls];
    updatedUrls.removeAt(index);
    onImagesChanged(updatedUrls, newFiles);
  }

  void _removeNewImage(int index) {
    final updatedFiles = [...newFiles];
    updatedFiles.removeAt(index);
    onImagesChanged(existingUrls, updatedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final totalImages = existingUrls.length + newFiles.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: totalImages + (totalImages < maxImages ? 1 : 0),
      itemBuilder: (context, index) {
        // Existing images
        if (index < existingUrls.length) {
          return _buildImageCard(
            isDarkMode: isDarkMode,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: existingUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D67D),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeExistingImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // New file images
        final fileIndex = index - existingUrls.length;
        if (fileIndex < newFiles.length) {
          return _buildImageCard(
            isDarkMode: isDarkMode,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    newFiles[fileIndex],
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _removeNewImage(fileIndex),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Add photo button
        return _buildImageCard(
          isDarkMode: isDarkMode,
          child: InkWell(
            onTap: () => _pickImage(context),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 32,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Photo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white38 : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCard({
    required bool isDarkMode,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: child,
    );
  }
}
