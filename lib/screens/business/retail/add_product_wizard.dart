import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import '../../../models/product_model.dart';
import '../../../services/business_service.dart';
import '../base_listing_wizard.dart';
import '../../../widgets/business/listings/photo_upload_grid.dart';
import '../../../widgets/business/listings/tags_input.dart';
import '../../../widgets/business/listings/ai_description_button.dart';

/// Retail product wizard implementation
/// Extends BaseListingWizard to create/edit retail products
class AddProductWizard extends BaseListingWizard {
  const AddProductWizard({
    super.key,
    required super.business,
    super.existingItem,
  });

  @override
  State<AddProductWizard> createState() => _AddProductWizardState();
}

class _AddProductWizardState extends BaseListingWizardState<AddProductWizard> {
  final BusinessService _businessService = BusinessService();

  // Product-specific fields
  String productName = '';
  String categoryId = '';
  String categoryName = '';
  String condition = 'New';
  String sku = '';
  String shortDescription = '';
  List<String> deliveryMethods = [];
  int stock = 0;
  double originalPrice = 0.0;
  bool isFeatured = false;
  bool inStock = true;
  String currency = 'INR';

  // Category management
  List<ProductCategoryModel> categories = [];
  bool isLoadingCategories = false;

  // Photo tracking (new files to upload)
  List<File> newPhotoFiles = [];
  List<String> existingPhotoUrls = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => isLoadingCategories = true);
    try {
      final loadedCategories =
          await _businessService.getProductCategories(widget.business.id);
      setState(() {
        categories = loadedCategories;
        isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => isLoadingCategories = false);
      if (mounted) {
        showError('Error loading categories: ${e.toString()}');
      }
    }
  }

  @override
  void loadExistingData(dynamic existingItem) {
    if (existingItem is ProductModel) {
      setState(() {
        productName = existingItem.name;
        categoryId = existingItem.categoryId;
        sku = existingItem.sku ?? '';
        existingPhotoUrls = List<String>.from(existingItem.images);
        shortDescription = existingItem.description?.substring(
                0,
                existingItem.description!.length > 100
                    ? 100
                    : existingItem.description!.length) ??
            '';
        description = existingItem.description ?? '';
        tags = List<String>.from(existingItem.tags);
        stock = existingItem.stock;
        price = existingItem.price;
        originalPrice = existingItem.originalPrice ?? 0.0;
        inStock = existingItem.inStock;
        isFeatured = existingItem.isFeatured;
        allowOffers = true; // Default for editing
        autoRenew = existingItem.isActive;
        currency = existingItem.currency;

        // Extract condition from attributes
        condition = existingItem.attributes['condition'] ?? 'New';

        // Extract delivery methods from attributes
        final deliveryAttr = existingItem.attributes['deliveryMethods'];
        if (deliveryAttr is List) {
          deliveryMethods = List<String>.from(deliveryAttr);
        }
      });
    }
  }

  @override
  Widget buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos & Basic Info',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add photos and basic information about your product',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Photos
        const Text(
          'Product Photos (Up to 10)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        PhotoUploadGrid(
          existingUrls: existingPhotoUrls,
          newFiles: newPhotoFiles,
          maxImages: 10,
          onImagesChanged: (urls, files) {
            setState(() {
              existingPhotoUrls = urls;
              newPhotoFiles = files;
            });
          },
        ),
        const SizedBox(height: 24),

        // Product Name
        const Text(
          'Product Name *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: productName)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: productName.length),
            ),
          onChanged: (value) => setState(() => productName = value),
          decoration: InputDecoration(
            hintText: 'Enter product name',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 20),

        // Category
        const Text(
          'Category *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : categories.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No categories found. Create a category first.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: categoryId.isEmpty ? null : categoryId,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Select category',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF7C3AED), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        categoryId = value ?? '';
                        categoryName = categories
                                .firstWhere((c) => c.id == value)
                                .name;
                      });
                    },
                  ),
        const SizedBox(height: 20),

        // Condition
        const Text(
          'Condition *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: ['New', 'Used', 'Refurbished'].map((cond) {
            final isSelected = condition == cond;
            return ChoiceChip(
              label: Text(cond),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => condition = cond);
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF7C3AED) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // SKU (Optional)
        const Text(
          'SKU (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: sku)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: sku.length),
            ),
          onChanged: (value) => setState(() => sku = value),
          decoration: InputDecoration(
            hintText: 'Enter SKU code',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description & Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Provide detailed information about your product',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Short Description
        const Text(
          'Short Description (100 chars)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: shortDescription)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: shortDescription.length),
            ),
          onChanged: (value) => setState(() => shortDescription = value),
          maxLength: 100,
          decoration: InputDecoration(
            hintText: 'Brief product description',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 20),

        // Full Description
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Full Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            AIDescriptionButton(
              listingTitle: productName,
              category: categoryName,
              onDescriptionGenerated: (generatedDesc) {
                setState(() => description = generatedDesc);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: description)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: description.length),
            ),
          onChanged: (value) => setState(() => description = value),
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Detailed product description',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 24),

        // Tags
        TagsInput(
          tags: tags,
          onTagsChanged: (newTags) => setState(() => tags = newTags),
          maxTags: 5,
        ),
        const SizedBox(height: 24),

        // Delivery Methods
        const Text(
          'Delivery Methods',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children:
              ['Shipping', 'Pickup', 'Local Delivery'].map((method) {
            final isSelected = deliveryMethods.contains(method);
            return ChoiceChip(
              label: Text(method),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    deliveryMethods.add(method);
                  } else {
                    deliveryMethods.remove(method);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF7C3AED) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Quantity/Stock
        const Text(
          'Quantity/Stock',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: stock.toString())
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: stock.toString().length),
            ),
          onChanged: (value) => setState(() => stock = int.tryParse(value) ?? 0),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter stock quantity',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visibility & Sales',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure pricing and visibility settings',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Price
        const Text(
          'Price *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _getCurrencySymbol(currency),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: price > 0 ? price.toString() : '')
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: price > 0 ? price.toString().length : 0),
                  ),
                onChanged: (value) =>
                    setState(() => price = double.tryParse(value) ?? 0.0),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Original Price (for discounts)
        const Text(
          'Original Price (Optional, for discounts)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _getCurrencySymbol(currency),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: TextEditingController(
                    text: originalPrice > 0 ? originalPrice.toString() : '')
                  ..selection = TextSelection.fromPosition(
                    TextPosition(
                        offset: originalPrice > 0
                            ? originalPrice.toString().length
                            : 0),
                  ),
                onChanged: (value) =>
                    setState(() => originalPrice = double.tryParse(value) ?? 0.0),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Toggles
        _buildToggle(
          'In Stock',
          inStock,
          (value) => setState(() => inStock = value),
        ),
        const SizedBox(height: 16),
        _buildToggle(
          'Featured',
          isFeatured,
          (value) => setState(() => isFeatured = value),
        ),
        const SizedBox(height: 16),
        _buildToggle(
          'Allow Offers',
          allowOffers,
          (value) => setState(() => allowOffers = value),
        ),
        const SizedBox(height: 16),
        _buildToggle(
          'Auto Renew',
          autoRenew,
          (value) => setState(() => autoRenew = value),
        ),
        const SizedBox(height: 24),

        // Pickup Address
        const Text(
          'Pickup Address (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: pickupAddress ?? '')
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: pickupAddress?.length ?? 0),
            ),
          onChanged: (value) => setState(() => pickupAddress = value),
          decoration: InputDecoration(
            hintText: 'Enter pickup address',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            suffixIcon: IconButton(
              icon: const Icon(Icons.location_on, color: Color(0xFF7C3AED)),
              onPressed: () {
                // TODO: Implement location picker
                showError('Location picker not yet implemented');
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildToggle(
          'Show Exact Address',
          showExactAddress,
          (value) => setState(() => showExactAddress = value),
        ),
      ],
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  @override
  bool validateStep(int step) {
    switch (step) {
      case 0:
        // Step 1: Photos & Basic Info
        if (productName.trim().isEmpty) {
          showError('Please enter product name');
          return false;
        }
        if (categoryId.isEmpty) {
          showError('Please select a category');
          return false;
        }
        if (existingPhotoUrls.isEmpty && newPhotoFiles.isEmpty) {
          showError('Please add at least one product photo');
          return false;
        }
        return true;

      case 1:
        // Step 2: Description & Details
        if (shortDescription.trim().isEmpty) {
          showError('Please enter a short description');
          return false;
        }
        if (deliveryMethods.isEmpty) {
          showError('Please select at least one delivery method');
          return false;
        }
        return true;

      case 2:
        // Step 3: Visibility & Sales
        if (price <= 0) {
          showError('Please enter a valid price');
          return false;
        }
        if (originalPrice > 0 && originalPrice <= price) {
          showError('Original price must be greater than current price');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  @override
  Future<void> saveData() async {
    final userId = FirebaseProvider.auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Upload new photos to Firebase Storage
    final uploadedUrls = <String>[];
    for (final file in newPhotoFiles) {
      setState(() => isSaving = true);
      final url = await _businessService.uploadListingImage(file);
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    // Combine existing and new photo URLs
    final allPhotoUrls = [...existingPhotoUrls, ...uploadedUrls];

    // Create product model
    final product = ProductModel(
      id: widget.existingItem?.id ?? '',
      categoryId: categoryId,
      businessId: widget.business.id,
      name: productName,
      description: description.isEmpty ? shortDescription : description,
      price: price,
      originalPrice: originalPrice > 0 ? originalPrice : null,
      currency: currency,
      images: allPhotoUrls,
      stock: stock,
      inStock: inStock,
      trackInventory: true,
      sku: sku.isEmpty ? null : sku,
      attributes: {
        'condition': condition,
        'deliveryMethods': deliveryMethods,
        'shortDescription': shortDescription,
      },
      isFeatured: isFeatured,
      isActive: autoRenew,
      tags: tags,
    );

    // Save to Firestore
    if (widget.existingItem == null) {
      // Create new product
      final productId = await _businessService.createProduct(product);
      if (productId == null) {
        throw Exception('Failed to create product');
      }
    } else {
      // Update existing product
      final success = await _businessService.updateProduct(
        widget.business.id,
        widget.existingItem!.id,
        product,
      );
      if (!success) {
        throw Exception('Failed to update product');
      }
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      default:
        return code;
    }
  }
}
