import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product_model.dart';
import '../../../services/business_service.dart';

/// Screen for adding/editing a product
class ProductFormScreen extends StatefulWidget {
  final String businessId;
  final String? categoryId;
  final ProductModel? product;
  final VoidCallback onSaved;

  const ProductFormScreen({
    super.key,
    required this.businessId,
    this.categoryId,
    this.product,
    required this.onSaved,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final BusinessService _businessService = BusinessService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;

  String? _selectedCategoryId;
  bool _inStock = true;
  bool _isFeatured = false;
  List<String> _selectedTags = [];
  Map<String, String> _attributes = {};
  bool _isSaving = false;

  bool get isEditing => widget.product != null;

  final List<String> _availableTags = [
    'New Arrival',
    'Best Seller',
    'Limited Edition',
    'Sale',
    'Trending',
    'Premium',
    'Eco-Friendly',
    'Handmade',
  ];

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(
      text: product?.price.toStringAsFixed(0) ?? '',
    );
    _originalPriceController = TextEditingController(
      text: product?.originalPrice?.toStringAsFixed(0) ?? '',
    );
    _stockController = TextEditingController(
      text: product?.stock.toString() ?? '0',
    );
    _skuController = TextEditingController(text: product?.sku ?? '');

    _selectedCategoryId = product?.categoryId ?? widget.categoryId;

    if (product != null) {
      _inStock = product.inStock;
      _isFeatured = product.isFeatured;
      _selectedTags = List.from(product.tags);
      _attributes = Map.from(product.attributes);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
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
          isEditing ? 'Edit Product' : 'Add Product',
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
            _buildSectionTitle('Basic Information', isDarkMode),
            const SizedBox(height: 16),
            _buildCategorySelector(isDarkMode),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Product Name',
              hint: 'e.g., Blue Denim Jacket',
              isDarkMode: isDarkMode,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe this product...',
              isDarkMode: isDarkMode,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _skuController,
              label: 'SKU (Optional)',
              hint: 'Product code',
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Pricing & Stock', isDarkMode),
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
            const SizedBox(height: 16),
            _buildTextField(
              controller: _stockController,
              label: 'Stock Quantity',
              hint: '0',
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Tags', isDarkMode),
            const SizedBox(height: 16),
            _buildTagsSelector(isDarkMode),
            const SizedBox(height: 24),
            _buildSectionTitle('Attributes', isDarkMode),
            const SizedBox(height: 8),
            Text(
              'Add product variants like size, color, etc.',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            _buildAttributesSection(isDarkMode),
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

  Widget _buildCategorySelector(bool isDarkMode) {
    return StreamBuilder<List<ProductCategoryModel>>(
      stream: _businessService.watchProductCategories(widget.businessId),
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

  Widget _buildTagsSelector(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableTags.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return GestureDetector(
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00D67D).withValues(alpha: 0.15)
                  : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check,
                    size: 14,
                    color: Color(0xFF00D67D),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF00D67D)
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

  Widget _buildAttributesSection(bool isDarkMode) {
    return Column(
      children: [
        // Existing attributes
        ..._attributes.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
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
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _attributes.remove(entry.key);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        // Add attribute button
        OutlinedButton.icon(
          onPressed: () => _showAddAttributeDialog(isDarkMode),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00D67D),
            side: const BorderSide(color: Color(0xFF00D67D)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Attribute'),
        ),
      ],
    );
  }

  Future<void> _showAddAttributeDialog(bool isDarkMode) async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: Text(
          'Add Attribute',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              autofocus: true,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Attribute Name',
                hintText: 'e.g., Size, Color',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Value',
                hintText: 'e.g., Large, Red',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (keyController.text.trim().isNotEmpty &&
                  valueController.text.trim().isNotEmpty) {
                setState(() {
                  _attributes[keyController.text.trim()] =
                      valueController.text.trim();
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusToggles(bool isDarkMode) {
    return Column(
      children: [
        _StatusToggle(
          title: 'In Stock',
          subtitle: _inStock
              ? 'This product is available for purchase'
              : 'This product is marked as out of stock',
          value: _inStock,
          onChanged: (value) => setState(() => _inStock = value),
          isDarkMode: isDarkMode,
          activeColor: Colors.green,
        ),
        const SizedBox(height: 12),
        _StatusToggle(
          title: 'Featured',
          subtitle: 'Show this product in featured section',
          value: _isFeatured,
          onChanged: (value) => setState(() => _isFeatured = value),
          isDarkMode: isDarkMode,
          activeColor: Colors.amber,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSaveButton(bool isDarkMode) {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveProduct,
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
              isEditing ? 'Save Changes' : 'Add Product',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final product = ProductModel(
        id: widget.product?.id ?? '',
        categoryId: _selectedCategoryId ?? '',
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
        images: widget.product?.images ?? [],
        stock: int.tryParse(_stockController.text) ?? 0,
        inStock: _inStock,
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        tags: _selectedTags,
        attributes: _attributes,
        isFeatured: _isFeatured,
      );

      if (isEditing) {
        await _businessService.updateProduct(widget.businessId, product.id, product);
      } else {
        await _businessService.createProduct(product);
      }

      if (mounted) {
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
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
