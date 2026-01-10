import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/service_model.dart';
import '../../services/professional_service.dart';

/// Bottom sheet for adding/editing a service
class AddServiceSheet extends StatefulWidget {
  final ServiceModel? existingService;
  final Function(ServiceModel) onSave;

  const AddServiceSheet({
    super.key,
    this.existingService,
    required this.onSave,
  });

  /// Show the bottom sheet
  static Future<void> show(
    BuildContext context, {
    ServiceModel? existingService,
    required Function(ServiceModel) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddServiceSheet(
        existingService: existingService,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<AddServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _tagController = TextEditingController();

  String _selectedCategory = ServiceCategories.all.first;
  PricingType _selectedPricingType = PricingType.fixed;
  String _selectedCurrency = 'USD';
  List<String> _tags = [];
  List<String> _imageUrls = [];
  final List<File> _newImages = [];

  bool _isLoading = false;
  bool _hasChanges = false;

  final ProfessionalService _professionalService = ProfessionalService();
  final ImagePicker _imagePicker = ImagePicker();

  bool get isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final service = widget.existingService!;
    _titleController.text = service.title;
    _descriptionController.text = service.description;
    _priceController.text = service.price?.toString() ?? '';
    _deliveryController.text = service.deliveryTime ?? '';
    _selectedCategory = service.category;
    _selectedPricingType = service.pricingType;
    _selectedCurrency = service.currency;
    _tags = List.from(service.tags);
    _imageUrls = List.from(service.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _deliveryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _pickImage() async {
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
        final image = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() {
            _newImages.add(File(image.path));
            _hasChanges = true;
          });
        }
      } catch (e) {
        debugPrint('Error picking image: $e');
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
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 5) {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload new images
      List<String> allImageUrls = List.from(_imageUrls);
      for (final imageFile in _newImages) {
        final url = await _professionalService.uploadServiceImage(imageFile);
        if (url != null) {
          allImageUrls.add(url);
        }
      }

      final service = ServiceModel(
        id: widget.existingService?.id ?? '',
        userId: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        price: _selectedPricingType == PricingType.negotiable
            ? null
            : double.tryParse(_priceController.text),
        pricingType: _selectedPricingType,
        currency: _selectedCurrency,
        deliveryTime: _deliveryController.text.trim().isEmpty
            ? null
            : _deliveryController.text.trim(),
        images: allImageUrls,
        tags: _tags,
        isActive: widget.existingService?.isActive ?? true,
        views: widget.existingService?.views ?? 0,
        inquiries: widget.existingService?.inquiries ?? 0,
      );

      widget.onSave(service);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save service')),
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
                            label: 'Service Title',
                            hint: 'e.g., Professional Logo Design',
                            icon: Icons.work_outline,
                            isDarkMode: isDarkMode,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Description
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Describe what you offer...',
                            icon: Icons.description_outlined,
                            isDarkMode: isDarkMode,
                            maxLines: 4,
                            maxLength: 500,
                            validator: (v) => v?.isEmpty == true
                                ? 'Description is required'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Category dropdown
                          _buildCategoryDropdown(isDarkMode),
                          const SizedBox(height: 16),

                          // Pricing type
                          _buildPricingTypeSelector(isDarkMode),
                          const SizedBox(height: 16),

                          // Price input (if not negotiable)
                          if (_selectedPricingType != PricingType.negotiable)
                            _buildPriceInput(isDarkMode),

                          const SizedBox(height: 16),

                          // Delivery time
                          _buildTextField(
                            controller: _deliveryController,
                            label: 'Delivery Time (Optional)',
                            hint: 'e.g., 3-5 days, 1 week',
                            icon: Icons.schedule,
                            isDarkMode: isDarkMode,
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
              isEditing ? 'Edit Service' : 'Add Service',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Images',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 12),
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
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                ),
              ),

              // Existing images
              ..._imageUrls.asMap().entries.map((entry) {
                return _buildImageTile(
                  isDarkMode,
                  imageUrl: entry.value,
                  onRemove: () => _removeImage(entry.key),
                );
              }),

              // New images
              ..._newImages.asMap().entries.map((entry) {
                return _buildImageTile(
                  isDarkMode,
                  file: entry.value,
                  onRemove: () => _removeImage(entry.key, isNewImage: true),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile(
    bool isDarkMode, {
    String? imageUrl,
    File? file,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[300]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                )
              : Image.file(file!, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 16,
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
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
        if (v != null) {
          setState(() {
            _selectedCategory = v;
            _hasChanges = true;
          });
        }
      },
      decoration: InputDecoration(
        labelText: 'Category',
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
      items: ServiceCategories.all.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Text(ServiceCategories.getIcon(category)),
              const SizedBox(width: 8),
              Text(category),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricingTypeSelector(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pricing Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: PricingType.values.map((type) {
            final isSelected = _selectedPricingType == type;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPricingType = type;
                  _hasChanges = true;
                });
                HapticFeedback.lightImpact();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                      : (isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF00D67D)
                        : (isDarkMode ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceInput(bool isDarkMode) {
    return Row(
      children: [
        // Currency selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCurrency,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedCurrency = v;
                    _hasChanges = true;
                  });
                }
              },
              dropdownColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              items: SupportedCurrencies.all.map((currency) {
                return DropdownMenuItem(
                  value: currency['code'],
                  child: Text('${currency['symbol']} ${currency['code']}'),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Price input
        Expanded(
          child: TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: (_) => _markChanged(),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: 'Price',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600]),
              labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[700]),
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
            ),
            validator: (v) {
              if (_selectedPricingType != PricingType.negotiable) {
                if (v?.isEmpty == true) return 'Price is required';
                if (double.tryParse(v!) == null) return 'Invalid price';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (up to 5)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black87,
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
              onPressed: _tags.length < 5 ? _addTag : null,
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
      ],
    );
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
                isEditing ? 'Save Changes' : 'Create Service',
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
