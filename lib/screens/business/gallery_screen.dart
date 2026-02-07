import '../../../services/firebase_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/business_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/business_widgets.dart';

/// Gallery management screen for business photos
class GalleryScreen extends StatefulWidget {
  final BusinessModel business;

  const GalleryScreen({
    super.key,
    required this.business,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  List<String> _images = [];
  bool _isLoading = false;
  bool _isReorderMode = false;
  final Set<int> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _images = List<String>.from(widget.business.images);
  }

  Future<void> _addImages() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    try {
      List<XFile> pickedFiles = [];

      if (source == ImageSource.camera) {
        final file = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        if (file != null) pickedFiles.add(file);
      } else {
        pickedFiles = await _imagePicker.pickMultiImage(
          imageQuality: 80,
          limit: 10,
        );
      }

      if (pickedFiles.isEmpty) return;

      setState(() => _isLoading = true);

      for (final file in pickedFiles) {
        final imageUrl = await _businessService.uploadGalleryImage(File(file.path));
        if (imageUrl != null) {
          _images.add(imageUrl);
        }
      }

      await _saveImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length} image(s) added'),
            backgroundColor: const Color(0xFF00D67D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF00D67D)),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Use camera to capture a new photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF42A5F5)),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Select multiple photos from your gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedImages() async {
    if (_selectedImages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text('Delete ${_selectedImages.length} selected photo(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final indicesToRemove = _selectedImages.toList()..sort((a, b) => b.compareTo(a));
      for (final index in indicesToRemove) {
        _images.removeAt(index);
      }
      _selectedImages.clear();
      await _saveImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveImages() async {
    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .update({
      'images': _images,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _toggleReorderMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _isReorderMode = !_isReorderMode;
      _selectedImages.clear();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final image = _images.removeAt(oldIndex);
      _images.insert(newIndex, image);
    });
    HapticFeedback.selectionClick();
    _saveImages();
  }

  void _toggleImageSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedImages.contains(index)) {
        _selectedImages.remove(index);
      } else {
        _selectedImages.add(index);
      }
    });
  }

  void _viewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageView(
          images: _images,
          initialIndex: index,
          onDelete: (idx) async {
            setState(() {
              _images.removeAt(idx);
            });
            await _saveImages();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedImages.isNotEmpty
              ? '${_selectedImages.length} selected'
              : 'Photo Gallery',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectedImages.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteSelectedImages,
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
              onPressed: () => setState(() => _selectedImages.clear()),
            ),
          ] else ...[
            if (_images.length > 1)
              IconButton(
                icon: Icon(
                  _isReorderMode ? Icons.check : Icons.swap_vert,
                  color: _isReorderMode
                      ? const Color(0xFF00D67D)
                      : (isDarkMode ? Colors.white70 : Colors.grey[600]),
                ),
                onPressed: _toggleReorderMode,
                tooltip: _isReorderMode ? 'Done reordering' : 'Reorder photos',
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D67D)))
          : _images.isEmpty
              ? BusinessEmptyState.gallery(onAddPressed: _addImages)
              : _buildGalleryGrid(isDarkMode),
      floatingActionButton: _images.isNotEmpty && !_isReorderMode
          ? FloatingActionButton(
              onPressed: _addImages,
              backgroundColor: const Color(0xFF00D67D),
              child: const Icon(Icons.add_photo_alternate, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildGalleryGrid(bool isDarkMode) {
    if (_isReorderMode) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _images.length,
        onReorder: _onReorder,
        itemBuilder: (context, index) {
          return _buildReorderableItem(index, isDarkMode);
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) => _buildGalleryItem(index, isDarkMode),
    );
  }

  Widget _buildReorderableItem(int index, bool isDarkMode) {
    return Container(
      key: ValueKey(_images[index]),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: _images[index],
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: 56,
              height: 56,
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              child: const Icon(Icons.image, color: Colors.grey),
            ),
            errorWidget: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          'Photo ${index + 1}',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          index == 0 ? 'Cover photo' : 'Gallery photo',
          style: TextStyle(
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(
            Icons.drag_handle,
            color: isDarkMode ? Colors.white38 : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryItem(int index, bool isDarkMode) {
    final isSelected = _selectedImages.contains(index);

    return GestureDetector(
      onTap: () {
        if (_selectedImages.isNotEmpty) {
          _toggleImageSelection(index);
        } else {
          _viewImage(index);
        }
      },
      onLongPress: () => _toggleImageSelection(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00D67D) : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: _images[index],
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: isDarkMode ? Colors.white10 : Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => Container(
                  color: isDarkMode ? Colors.white10 : Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              // Cover photo badge
              if (index == 0)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'COVER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D67D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen image viewer with swipe navigation
class _FullScreenImageView extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final Function(int) onDelete;

  const _FullScreenImageView({
    required this.images,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<_FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      widget.onDelete(_currentIndex);
      if (widget.images.length <= 1) {
        Navigator.pop(context);
      } else {
        setState(() {
          if (_currentIndex >= widget.images.length) {
            _currentIndex = widget.images.length - 1;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _deleteImage,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                ),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
