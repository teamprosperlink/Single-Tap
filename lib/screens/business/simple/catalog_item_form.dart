import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
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
  CatalogItemType _type = CatalogItemType.service;
  bool _isAvailable = true;
  int _durationDays = 0;
  final _durationDaysController = TextEditingController();
  String _currency = 'INR';
  final List<File> _newImageFiles = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;

  static const int _maxImages = 5;

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
      _existingImageUrls = List<String>.from(item.allImages);
      if (item.duration != null) {
        _durationDays = item.duration! ~/ (24 * 60);
        _durationDaysController.text = _durationDays > 0 ? '$_durationDays' : '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationDaysController.dispose();
    super.dispose();
  }

  bool get _showDuration => _type == CatalogItemType.service;

  int get _totalImageCount => _existingImageUrls.length + _newImageFiles.length;

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImageCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 5 images allowed'),
          backgroundColor: AppTheme.warningStatus,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked.isNotEmpty) {
      final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
      setState(() => _newImageFiles.addAll(toAdd));
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImageFiles.removeAt(index));
  }

  int? _computeDuration() {
    final total = _durationDays * 24 * 60;
    return total > 0 ? total : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload new images
      final newUrls = await _catalogService.uploadCatalogImages(
          _newImageFiles, userId);

      // Combine existing + new
      final allUrls = [..._existingImageUrls, ...newUrls];
      final firstUrl = allUrls.isNotEmpty ? allUrls.first : null;

      final priceText = _priceController.text.trim();
      final price = priceText.isNotEmpty ? double.tryParse(priceText) : null;
      final duration = _showDuration ? _computeDuration() : null;

      if (widget.isEditing) {
        await _catalogService.updateItem(userId, widget.item!.id, {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'price': price,
          'currency': _currency,
          'imageUrl': firstUrl,
          'imageUrls': allUrls,
          'type': _type.name,
          'isAvailable': _isAvailable,
          'duration': duration,
        });
      } else {
        final item = CatalogItem(
          id: '',
          userId: userId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          price: price,
          currency: _currency,
          imageUrl: firstUrl,
          imageUrls: allUrls,
          type: _type,
          isAvailable: _isAvailable,
          duration: duration,
        );

        final itemId = await _catalogService.addItem(item);
        if (itemId == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Could not add item. You have reached the 100 item limit.'),
              backgroundColor: AppTheme.errorStatus,
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
          backgroundColor: AppTheme.successStatus,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorStatus),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.backgroundColor(isDark);
    final cardColor = AppTheme.cardColor(isDark);
    final textColor = AppTheme.textPrimary(isDark);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final currencySymbol = _currency == 'USD' ? '\$' : '\u20B9';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isEditing ? 'Edit Item' : 'Add New Item'),
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
                : Text('Save',
                    style: TextStyle(
                        color: AppTheme.primaryAction,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Item Type chips ──
            Text('Item Type',
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeChip('Service', CatalogItemType.service,
                    Icons.build_outlined, isDark),
                const SizedBox(width: 8),
                _typeChip('Product', CatalogItemType.product,
                    Icons.shopping_bag_outlined, isDark),
              ],
            ),

            const SizedBox(height: 20),

            // ── Item Images ──
            Row(
              children: [
                Text('Item Images',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('($_totalImageCount/$_maxImages)',
                    style: TextStyle(color: subtitleColor, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            _buildImageSection(isDark, cardColor, textColor, subtitleColor),

            const SizedBox(height: 20),

            // ── Item Name ──
            Text('Item Name',
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: _inputDecoration(
                _type == CatalogItemType.service
                    ? 'e.g., Hair Cut & Styling'
                    : 'e.g., Organic Shampoo',
                isDark,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),

            const SizedBox(height: 16),

            // ── Description ──
            Text('Description',
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: textColor),
              decoration: _inputDecoration('Describe your item...', isDark),
              maxLines: 3,
              maxLength: 500,
            ),

            const SizedBox(height: 12),

            // ── Price ──
            Text('Price',
                style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _priceController,
              style: TextStyle(color: textColor),
              decoration: _inputDecoration('0.00', isDark).copyWith(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(currencySymbol,
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              keyboardType: TextInputType.number,
            ),

            // ── Duration (Service only) ──
            if (_showDuration) ...[
              const SizedBox(height: 16),
              Text('Duration',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _durationDaysController,
                style: TextStyle(color: textColor),
                decoration: _inputDecoration('e.g., 7', isDark).copyWith(
                  suffixText: 'days',
                  suffixStyle: TextStyle(color: subtitleColor, fontSize: 14),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _durationDays = int.tryParse(v) ?? 0,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = int.tryParse(v.trim());
                  if (val == null || val < 1 || val > 30) {
                    return 'Enter between 1 and 30 days';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 20),

            // ── Active Status ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active Status',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Make this item available to customers',
                            style:
                                TextStyle(color: subtitleColor, fontSize: 13)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeThumbColor: AppTheme.primaryAction,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Save Button ──
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAction,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        widget.isEditing ? 'Update Item' : 'Save Item',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(
      bool isDark, Color cardColor, Color textColor, Color subtitleColor) {
    final hasImages = _existingImageUrls.isNotEmpty || _newImageFiles.isNotEmpty;

    if (!hasImages) {
      // Empty state — tap to add
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 32, color: subtitleColor),
                const SizedBox(height: 8),
                Text('Upload Images',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Up to $_maxImages photos',
                    style: TextStyle(color: subtitleColor, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAction.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Select Files',
                      style: TextStyle(
                          color: AppTheme.primaryAction,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Image thumbnails grid
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing (uploaded) images
          for (int i = 0; i < _existingImageUrls.length; i++)
            _imageThumbnail(
              isDark: isDark,
              child: Image.network(_existingImageUrls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white38)),
              onRemove: () => _removeExistingImage(i),
            ),
          // New (local) images
          for (int i = 0; i < _newImageFiles.length; i++)
            _imageThumbnail(
              isDark: isDark,
              child: Image.file(_newImageFiles[i], fit: BoxFit.cover),
              onRemove: () => _removeNewImage(i),
            ),
          // Add more button
          if (_totalImageCount < _maxImages)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryAction.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: AppTheme.primaryAction, size: 28),
                    const SizedBox(height: 4),
                    Text('Add',
                        style: TextStyle(
                            color: AppTheme.primaryAction,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageThumbnail({
    required bool isDark,
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.expand(child: child),
          ),
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
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryAction
                : (isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: AppTheme.primaryAction)
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white60 : Colors.black45)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2E) : AppTheme.backgroundColor(false),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
