import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/menu_model.dart';
import '../../../services/business_service.dart';

/// Screen for adding/editing a menu item
class MenuItemFormScreen extends StatefulWidget {
  final String businessId;
  final String? categoryId;
  final MenuItemModel? item;
  final VoidCallback onSaved;

  const MenuItemFormScreen({
    super.key,
    required this.businessId,
    this.categoryId,
    this.item,
    required this.onSaved,
  });

  @override
  State<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends State<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _caloriesController;
  late TextEditingController _prepTimeController;

  String? _selectedCategoryId;
  FoodType _foodType = FoodType.nonVeg;
  SpiceLevel? _spiceLevel;
  List<String> _selectedTags = [];
  List<String> _selectedAllergens = [];
  bool _isAvailable = true;
  bool _isSaving = false;

  // Image management
  String? _existingImage;
  File? _newImage;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(
      text: item?.price.toStringAsFixed(0) ?? '',
    );
    _originalPriceController = TextEditingController(
      text: item?.originalPrice?.toStringAsFixed(0) ?? '',
    );
    _caloriesController = TextEditingController(
      text: item?.calories?.toString() ?? '',
    );
    _prepTimeController = TextEditingController(
      text: item?.preparationTime?.toString() ?? '',
    );

    _selectedCategoryId = item?.categoryId ?? widget.categoryId;

    if (item != null) {
      _foodType = item.foodType;
      _spiceLevel = item.spiceLevel;
      _selectedTags = List.from(item.tags);
      _selectedAllergens = List.from(item.allergens);
      _isAvailable = item.isAvailable;
      _existingImage = item.image;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _caloriesController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Menu Item' : 'Add Menu Item',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionTitle('Food Photo', isDarkMode),
            const SizedBox(height: 16),
            _buildImagePicker(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Basic Information', isDarkMode),
            const SizedBox(height: 16),
            _buildCategorySelector(isDarkMode),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Item Name',
              hint: 'e.g., Butter Chicken, Margherita Pizza',
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe this item...',
              isDarkMode: isDarkMode,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Food Type', isDarkMode),
            const SizedBox(height: 16),
            _buildFoodTypeSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Pricing', isDarkMode),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'Price',
                    hint: 'Enter price',
                    isDarkMode: isDarkMode,
                    prefixText: '\u20B9 ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _originalPriceController,
                    label: 'Original Price',
                    hint: 'For discounts',
                    isDarkMode: isDarkMode,
                    prefixText: '\u20B9 ',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Spice Level', isDarkMode),
            const SizedBox(height: 16),
            _buildSpiceLevelSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Additional Info', isDarkMode),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _caloriesController,
                    label: 'Calories',
                    hint: 'Optional',
                    isDarkMode: isDarkMode,
                    suffixText: 'kcal',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _prepTimeController,
                    label: 'Prep Time',
                    hint: 'Optional',
                    isDarkMode: isDarkMode,
                    suffixText: 'mins',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Tags', isDarkMode),
            const SizedBox(height: 16),
            _buildTagsSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Allergens', isDarkMode),
            const SizedBox(height: 16),
            _buildAllergensSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Status', isDarkMode),
            const SizedBox(height: 16),
            _buildStatusToggles(isDarkMode),
            const SizedBox(height: 32),
            _buildSaveButton(isDarkMode),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildImagePicker(bool isDarkMode) {
    final hasImage = _newImage != null || _existingImage != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: hasImage
          ? _buildImagePreview(isDarkMode)
          : _buildImagePlaceholder(isDarkMode),
    );
  }

  Widget _buildImagePlaceholder(bool isDarkMode) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF00D67D).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00D67D).withValues(alpha: 0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: isDarkMode ? Colors.white38 : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Add Food Photo',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to select image',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(bool isDarkMode) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (_newImage != null)
                Image.file(
                  _newImage!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              else if (_existingImage != null)
                Image.network(
                  _existingImage!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: isDarkMode ? Colors.white10 : Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D67D),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: isDarkMode ? Colors.white10 : Colors.grey[200],
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: isDarkMode ? Colors.white38 : Colors.grey[400],
                      ),
                    );
                  },
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    _buildImageActionButton(
                      icon: Icons.edit,
                      onTap: _pickImage,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 8),
                    _buildImageActionButton(
                      icon: Icons.delete,
                      onTap: _removeImage,
                      isDarkMode: isDarkMode,
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDarkMode,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.9)
              : (isDarkMode ? Colors.black54 : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive
              ? Colors.white
              : (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _newImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _newImage = null;
      _existingImage = null;
    });
  }

  Widget _buildCategorySelector(bool isDarkMode) {
    return StreamBuilder<List<MenuCategoryModel>>(
      stream: _businessService.watchMenuCategories(widget.businessId),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

        return DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          decoration: InputDecoration(
            labelText: 'Category',
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
            filled: true,
            fillColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
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
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
          hint: Text(
            categories.isEmpty ? 'No categories - create one first' : 'Select category',
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDarkMode,
    String? prefixText,
    String? suffixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.grey[600],
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white38 : Colors.grey[400],
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
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
          borderSide: const BorderSide(color: Color(0xFF00D67D), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildFoodTypeSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FoodType.values.map((type) {
        final isSelected = _foodType == type;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _foodType = type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _getFoodTypeColor(type).withValues(alpha: 0.15)
                  : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _getFoodTypeColor(type)
                    : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getFoodTypeColor(type),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  type.displayName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? _getFoodTypeColor(type)
                        : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getFoodTypeColor(FoodType type) {
    switch (type) {
      case FoodType.veg:
      case FoodType.vegan:
        return Colors.green;
      case FoodType.nonVeg:
        return Colors.red;
      case FoodType.egg:
        return Colors.amber;
    }
  }

  Widget _buildSpiceLevelSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SpiceLevelChip(
          label: 'None',
          isSelected: _spiceLevel == null,
          onTap: () => setState(() => _spiceLevel = null),
          isDarkMode: isDarkMode,
        ),
        ...SpiceLevel.values.map((level) {
          return _SpiceLevelChip(
            label: level.displayName,
            isSelected: _spiceLevel == level,
            onTap: () => setState(() => _spiceLevel = level),
            isDarkMode: isDarkMode,
            spiceLevel: level,
          );
        }),
      ],
    );
  }

  Widget _buildTagsSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MenuTags.all.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return _SelectableChip(
          label: tag,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSelected) {
                _selectedTags.remove(tag);
              } else {
                _selectedTags.add(tag);
              }
            });
          },
          isDarkMode: isDarkMode,
        );
      }).toList(),
    );
  }

  Widget _buildAllergensSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FoodAllergens.all.map((allergen) {
        final isSelected = _selectedAllergens.contains(allergen);
        return _SelectableChip(
          label: allergen,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSelected) {
                _selectedAllergens.remove(allergen);
              } else {
                _selectedAllergens.add(allergen);
              }
            });
          },
          isDarkMode: isDarkMode,
          selectedColor: Colors.orange,
        );
      }).toList(),
    );
  }

  Widget _buildStatusToggles(bool isDarkMode) {
    return _StatusToggle(
      title: 'Available',
      subtitle: _isAvailable
          ? 'This item is visible to customers'
          : 'This item is hidden from customers',
      value: _isAvailable,
      onChanged: (value) => setState(() => _isAvailable = value),
      isDarkMode: isDarkMode,
      activeColor: Colors.green,
    );
  }

  Widget _buildSaveButton(bool isDarkMode) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveItem,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D67D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              isEditing ? 'Save Changes' : 'Add Menu Item',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image if new one was selected
      String? imageUrl = _existingImage;
      if (_newImage != null) {
        final tempItemId = widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await _businessService.uploadMenuItemImage(
          widget.businessId,
          tempItemId,
          _newImage!,
        );
      }

      final item = MenuItemModel(
        id: widget.item?.id ?? '',
        categoryId: _selectedCategoryId!,
        businessId: widget.businessId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0,
        originalPrice: _originalPriceController.text.isEmpty
            ? null
            : double.tryParse(_originalPriceController.text),
        currency: 'INR',
        image: imageUrl,
        foodType: _foodType,
        spiceLevel: _spiceLevel,
        isAvailable: _isAvailable,
        tags: _selectedTags,
        allergens: _selectedAllergens,
        calories: _caloriesController.text.isEmpty
            ? null
            : int.tryParse(_caloriesController.text),
        preparationTime: _prepTimeController.text.isEmpty
            ? null
            : int.tryParse(_prepTimeController.text),
      );

      if (isEditing) {
        await _businessService.updateMenuItem(widget.businessId, item.id, item);
      } else {
        await _businessService.createMenuItem(item);
      }

      if (mounted) {
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _SpiceLevelChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final SpiceLevel? spiceLevel;

  const _SpiceLevelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.spiceLevel,
  });

  @override
  Widget build(BuildContext context) {
    final spiceColor = _getSpiceColor();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? spiceColor.withValues(alpha: 0.15)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? spiceColor
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spiceLevel != null) ...[
              ...List.generate(
                _getSpiceIntensity(),
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Text('🌶️', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? spiceColor
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSpiceColor() {
    if (spiceLevel == null) return Colors.grey;
    switch (spiceLevel!) {
      case SpiceLevel.mild:
        return Colors.yellow[700]!;
      case SpiceLevel.medium:
        return Colors.orange;
      case SpiceLevel.hot:
        return Colors.deepOrange;
      case SpiceLevel.extraHot:
        return Colors.red;
    }
  }

  int _getSpiceIntensity() {
    if (spiceLevel == null) return 0;
    switch (spiceLevel!) {
      case SpiceLevel.mild:
        return 1;
      case SpiceLevel.medium:
        return 2;
      case SpiceLevel.hot:
        return 3;
      case SpiceLevel.extraHot:
        return 4;
    }
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final Color selectedColor;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.selectedColor = const Color(0xFF00D67D),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check,
                size: 14,
                color: selectedColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? selectedColor
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDarkMode;
  final Color activeColor;

  const _StatusToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDarkMode,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              onChanged(val);
            },
            activeThumbColor: activeColor,
          ),
        ],
      ),
    );
  }
}
