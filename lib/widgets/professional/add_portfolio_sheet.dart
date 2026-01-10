import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/portfolio_item_model.dart';
import '../../services/professional_service.dart';

/// Bottom sheet for adding/editing a portfolio item
class AddPortfolioSheet extends StatefulWidget {
  final PortfolioItemModel? existingItem;
  final Function(PortfolioItemModel) onSave;

  const AddPortfolioSheet({
    super.key,
    this.existingItem,
    required this.onSave,
  });

  /// Show the bottom sheet
  static Future<void> show(
    BuildContext context, {
    PortfolioItemModel? existingItem,
    required Function(PortfolioItemModel) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPortfolioSheet(
        existingItem: existingItem,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddPortfolioSheet> createState() => _AddPortfolioSheetState();
}

class _AddPortfolioSheetState extends State<AddPortfolioSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectUrlController = TextEditingController();
  final _tagController = TextEditingController();

  String? _selectedCategory;
  List<String> _tags = [];
  List<String> _imageUrls = [];
  final List<File> _newImages = [];

  bool _isLoading = false;
  bool _hasChanges = false;

  final ProfessionalService _professionalService = ProfessionalService();
  final ImagePicker _imagePicker = ImagePicker();

  bool get isEditing => widget.existingItem != null;

  // Portfolio categories
  static const List<String> _categories = [
    'Design & Creative',
    'Web Development',
    'Mobile Development',
    'Writing & Content',
    'Marketing & SEO',
    'Video & Animation',
    'Music & Audio',
    'Business & Finance',
    'Education & Tutoring',
    'Photography',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final item = widget.existingItem!;
    _titleController.text = item.title;
    _descriptionController.text = item.description ?? '';
    _projectUrlController.text = item.projectUrl ?? '';
    _selectedCategory = item.category;
    _tags = List.from(item.tags);
    _imageUrls = List.from(item.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _projectUrlController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _pickImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2D2D44)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select multiple images'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        if (source == ImageSource.gallery) {
          // Allow multiple images for gallery
          final images = await _imagePicker.pickMultiImage(
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );

          if (images.isNotEmpty) {
            setState(() {
              for (final image in images) {
                if (_imageUrls.length + _newImages.length < 10) {
                  _newImages.add(File(image.path));
                }
              }
              _hasChanges = true;
            });
          }
        } else {
          final image = await _imagePicker.pickImage(
            source: source,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );

          if (image != null && _imageUrls.length + _newImages.length < 10) {
            setState(() {
              _newImages.add(File(image.path));
              _hasChanges = true;
            });
          }
        }
      } catch (e) {
        debugPrint('Error picking images: $e');
      }
    }
  }

  void _removeImage(int index, {bool isNewImage = false}) {
    setState(() {
      if (isNewImage) {
        _newImages.removeAt(index);
      } else {
        _imageUrls.removeAt(index);
      }
      _hasChanges = true;
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 8) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
        _hasChanges = true;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new images
      List<String> allImageUrls = List.from(_imageUrls);
      for (final imageFile in _newImages) {
        final url = await _professionalService.uploadPortfolioImage(imageFile);
        if (url != null) {
          allImageUrls.add(url);
        }
      }

      final item = PortfolioItemModel(
        id: widget.existingItem?.id ?? '',
        userId: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        images: allImageUrls,
        projectUrl: _projectUrlController.text.trim().isEmpty
            ? null
            : _projectUrlController.text.trim(),
        tags: _tags,
        category: _selectedCategory,
        order: widget.existingItem?.order ?? 0,
        isVisible: widget.existingItem?.isVisible ?? true,
      );

      widget.onSave(item);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving portfolio item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save portfolio item')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasChanges) {
          _showDiscardDialog();
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(isDarkMode),

                // Form content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20 + bottomPadding,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Images section
                          _buildImagesSection(isDarkMode),
                          const SizedBox(height: 24),

                          // Title
                          _buildTextField(
                            controller: _titleController,
                            label: 'Project Title',
                            hint: 'e.g., E-commerce Website Redesign',
                            icon: Icons.title,
                            isDarkMode: isDarkMode,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Description
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description (Optional)',
                            hint: 'Describe your project, the process, and outcome...',
                            icon: Icons.description_outlined,
                            isDarkMode: isDarkMode,
                            maxLines: 4,
                            maxLength: 800,
                          ),
                          const SizedBox(height: 16),

                          // Category dropdown
                          _buildCategoryDropdown(isDarkMode),
                          const SizedBox(height: 16),

                          // Project URL
                          _buildTextField(
                            controller: _projectUrlController,
                            label: 'Project URL (Optional)',
                            hint: 'https://...',
                            icon: Icons.link,
                            isDarkMode: isDarkMode,
                            keyboardType: TextInputType.url,
                            validator: (v) {
                              if (v != null && v.isNotEmpty && !_isValidUrl(v)) {
                                return 'Please enter a valid URL';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Tags
                          _buildTagsSection(isDarkMode),
                          const SizedBox(height: 32),

                          // Save button
                          _buildSaveButton(isDarkMode),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_hasChanges) {
                _showDiscardDialog();
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close),
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
          Expanded(
            child: Text(
              isEditing ? 'Edit Portfolio Item' : 'Add Portfolio Item',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Unsaved',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildImagesSection(bool isDarkMode) {
    final totalImages = _imageUrls.length + _newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Project Images',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              '$totalImages/10',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add up to 10 images. First image will be the cover.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 12),

        // Image grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: totalImages + (totalImages < 10 ? 1 : 0),
          itemBuilder: (context, index) {
            // Add button at the end
            if (index == totalImages) {
              return _buildAddImageButton(isDarkMode);
            }

            // Existing images
            if (index < _imageUrls.length) {
              return _buildImageGridTile(
                isDarkMode,
                index: index,
                imageUrl: _imageUrls[index],
                onRemove: () => _removeImage(index),
                isCover: index == 0,
              );
            }

            // New images
            final newIndex = index - _imageUrls.length;
            return _buildImageGridTile(
              isDarkMode,
              index: index,
              file: _newImages[newIndex],
              onRemove: () => _removeImage(newIndex, isNewImage: true),
              isCover: index == 0,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddImageButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: isDarkMode ? Colors.white54 : Colors.grey[500],
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGridTile(
    bool isDarkMode, {
    required int index,
    String? imageUrl,
    File? file,
    required VoidCallback onRemove,
    bool isCover = false,
  }) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isCover
                ? Border.all(color: const Color(0xFF00D67D), width: 2)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.grey[300]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                )
              : Image.file(file!, fit: BoxFit.cover),
        ),

        // Cover badge
        if (isCover)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Cover',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onChanged: (_) => _markChanged(),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon,
            color: isDarkMode ? Colors.white54 : Colors.grey[600]),
        labelStyle:
            TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700]),
        hintStyle:
            TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey[400]),
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF00D67D),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        counterStyle: TextStyle(color: Colors.grey[500]),
      ),
      validator: validator,
    );
  }

  Widget _buildCategoryDropdown(bool isDarkMode) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      onChanged: (v) {
        setState(() {
          _selectedCategory = v;
          _hasChanges = true;
        });
      },
      decoration: InputDecoration(
        labelText: 'Category (Optional)',
        prefixIcon: Icon(Icons.category_outlined,
            color: isDarkMode ? Colors.white54 : Colors.grey[600]),
        labelStyle:
            TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700]),
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
          ),
        ),
      ),
      dropdownColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Select category',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
        ..._categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
        }),
      ],
    );
  }

  Widget _buildTagsSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tags (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            Text(
              '${_tags.length}/8',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add keywords that describe your project',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 12),

        // Tag input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                onSubmitted: (_) => _addTag(),
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add a tag...',
                  hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.grey[400]),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _tags.length < 8 ? _addTag : null,
              icon: const Icon(Icons.add),
              color: const Color(0xFF00D67D),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tags display
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFF00D67D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeTag(tag),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        // Suggested tags
        if (_tags.length < 8 && _selectedCategory != null) ...[
          const SizedBox(height: 16),
          Text(
            'Suggested tags',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getSuggestedTags()
                .where((tag) => !_tags.contains(tag))
                .take(6)
                .map((tag) {
              return GestureDetector(
                onTap: () {
                  if (_tags.length < 8 && !_tags.contains(tag)) {
                    setState(() {
                      _tags.add(tag);
                      _hasChanges = true;
                    });
                    HapticFeedback.lightImpact();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 14,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  List<String> _getSuggestedTags() {
    final suggestions = <String, List<String>>{
      'Design & Creative': ['UI Design', 'UX', 'Branding', 'Logo', 'Illustration', 'Typography'],
      'Web Development': ['React', 'Vue', 'Angular', 'Node.js', 'WordPress', 'E-commerce'],
      'Mobile Development': ['Flutter', 'React Native', 'iOS', 'Android', 'Cross-platform', 'App Design'],
      'Writing & Content': ['Copywriting', 'Blog', 'Technical', 'SEO', 'Editing', 'Script'],
      'Marketing & SEO': ['SEO', 'PPC', 'Social Media', 'Email', 'Analytics', 'Strategy'],
      'Video & Animation': ['Motion Graphics', '2D Animation', '3D', 'Editing', 'VFX', 'YouTube'],
      'Music & Audio': ['Production', 'Mixing', 'Voice Over', 'Podcast', 'Sound Design', 'Jingles'],
      'Business & Finance': ['Strategy', 'Analysis', 'Planning', 'Consulting', 'Finance', 'Startup'],
      'Education & Tutoring': ['Online Course', 'Curriculum', 'E-learning', 'Training', 'Workshop'],
      'Photography': ['Portrait', 'Product', 'Event', 'Real Estate', 'Editing', 'Retouching'],
    };
    return suggestions[_selectedCategory] ?? [];
  }

  Widget _buildSaveButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D67D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                isEditing ? 'Save Changes' : 'Add to Portfolio',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
