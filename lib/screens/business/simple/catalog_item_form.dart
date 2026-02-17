import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/catalog_item.dart';
import '../../../services/catalog_service.dart';

class CatalogItemForm extends StatefulWidget {
  final CatalogItem? item;

  const CatalogItemForm({super.key, this.item});

  bool get isEditing => item != null;

  @override
  State<CatalogItemForm> createState() => _CatalogItemFormState();
}

class _CatalogItemFormState extends State<CatalogItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _catalogService = CatalogService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  CatalogItemType _type = CatalogItemType.product;
  bool _isAvailable = true;
  String _currency = 'INR';
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final item = widget.item!;
      _nameController.text = item.name;
      _descriptionController.text = item.description ?? '';
      _priceController.text =
          item.price != null ? item.price!.toString() : '';
      _type = item.type;
      _isAvailable = item.isAvailable;
      _currency = item.currency;
      _existingImageUrl = item.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        imageUrl =
            await _catalogService.uploadCatalogImage(_imageFile!, userId);
      }

      final priceText = _priceController.text.trim();
      final price = priceText.isNotEmpty ? double.tryParse(priceText) : null;

      if (widget.isEditing) {
        // Update existing item
        await _catalogService.updateItem(userId, widget.item!.id, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'price': price,
          'currency': _currency,
          'imageUrl': imageUrl,
          'type': _type.name,
          'isAvailable': _isAvailable,
        });
      } else {
        // Add new item
        final item = CatalogItem(
          id: '',
          userId: userId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          price: price,
          currency: _currency,
          imageUrl: imageUrl,
          type: _type,
          isAvailable: _isAvailable,
        );

        final itemId = await _catalogService.addItem(item);
        if (itemId == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not add item. You may have reached the 100 item limit.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'Item updated' : 'Item added'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Item' : 'Add Item'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : (_existingImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_existingImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: (_imageFile == null && _existingImageUrl == null)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text('Add Photo',
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 14)),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Form fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Item Name *', isDark),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: textColor),
                    decoration: _inputDecoration('Description', isDark),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Currency
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: _inputDecoration('', isDark).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          dropdownColor: cardColor,
                          isExpanded: true,
                          style: TextStyle(color: textColor, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                                value: 'INR', child: Text('\u20B9 INR')),
                            DropdownMenuItem(
                                value: 'USD', child: Text('\$ USD')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _currency = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Price
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration(
                              'Price (leave empty for "Contact")', isDark),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Type toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type',
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeChip('Product', CatalogItemType.product,
                          Icons.shopping_bag_outlined, isDark),
                      const SizedBox(width: 12),
                      _typeChip('Service', CatalogItemType.service,
                          Icons.home_repair_service_outlined, isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Available',
                        style: TextStyle(color: textColor, fontSize: 15)),
                    subtitle: Text(
                      _isAvailable
                          ? 'Visible to customers'
                          : 'Hidden from customers',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeThumbColor: const Color(0xFF22C55E),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(
      String label, CatalogItemType type, IconData icon, bool isDark) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                : (isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: const Color(0xFF22C55E)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF22C55E)
                      : (isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF22C55E)
                      : (isDark ? Colors.white : Colors.black),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label.isNotEmpty ? label : null,
      labelStyle: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.4),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
