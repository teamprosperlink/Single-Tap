import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/business_model.dart';
import '../../../models/business_post_model.dart';

/// Bottom sheet for creating or editing a business post
class CreatePostSheet extends StatefulWidget {
  final BusinessModel business;
  final PostType? initialType;
  final BusinessPost? existingPost;
  final Function(BusinessPost) onSave;

  const CreatePostSheet({
    super.key,
    required this.business,
    this.initialType,
    this.existingPost,
    required this.onSave,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _promoCodeController = TextEditingController();

  late PostType _selectedType;
  bool _isActive = true;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _postTypes = [
    {'type': PostType.update, 'icon': Icons.campaign, 'label': 'Update', 'color': Colors.blue},
    {'type': PostType.product, 'icon': Icons.shopping_bag, 'label': 'Product', 'color': Colors.teal},
    {'type': PostType.service, 'icon': Icons.build, 'label': 'Service', 'color': Colors.purple},
    {'type': PostType.promotion, 'icon': Icons.local_offer, 'label': 'Promotion', 'color': Colors.orange},
    {'type': PostType.portfolio, 'icon': Icons.photo_library, 'label': 'Portfolio', 'color': Colors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.existingPost?.type ?? widget.initialType ?? PostType.update;

    if (widget.existingPost != null) {
      _titleController.text = widget.existingPost!.title ?? '';
      _descriptionController.text = widget.existingPost!.description;
      _priceController.text = widget.existingPost!.price?.toString() ?? '';
      _originalPriceController.text = widget.existingPost!.originalPrice?.toString() ?? '';
      _promoCodeController.text = widget.existingPost!.promoCode ?? '';
      _isActive = widget.existingPost!.isActive;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingPost != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  isEditing ? 'Edit Post' : 'Create Post',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Type Selection
                    Text(
                      'Post Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _postTypes.map((item) {
                        final type = item['type'] as PostType;
                        final isSelected = _selectedType == type;
                        final color = item['color'] as Color;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedType = type);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? color : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 18,
                                  color: isSelected ? color : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected
                                        ? color
                                        : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Title (optional for updates)
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title ${_selectedType == PostType.update ? '(optional)' : ''}',
                        hintText: 'Enter title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _selectedType != PostType.update
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What do you want to share?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price fields for products, services, promotions
                    if (_selectedType == PostType.product ||
                        _selectedType == PostType.service ||
                        _selectedType == PostType.promotion) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Price',
                                prefixText: '\u{20B9} ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedType == PostType.promotion) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _originalPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Original Price',
                                  prefixText: '\u{20B9} ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Promo code for promotions
                    if (_selectedType == PostType.promotion) ...[
                      TextFormField(
                        controller: _promoCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Promo Code (optional)',
                          hintText: 'SUMMER20',
                          prefixIcon: const Icon(Icons.local_offer_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Active toggle
                    SwitchListTile(
                      title: Text(
                        'Publish Immediately',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _isActive ? 'Post will be visible to customers' : 'Save as draft',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      value: _isActive,
                      onChanged: (value) => setState(() => _isActive = value),
                      activeTrackColor: const Color(0xFF00D67D).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFF00D67D),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.white12 : Colors.grey[200]!,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Post',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final price = double.tryParse(_priceController.text);
    final originalPrice = double.tryParse(_originalPriceController.text);

    final post = BusinessPost(
      id: widget.existingPost?.id ?? '',
      businessId: widget.business.id,
      businessName: widget.business.businessName,
      businessLogo: widget.business.logo,
      type: _selectedType,
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      originalPrice: originalPrice,
      currency: 'INR',
      promoCode: _promoCodeController.text.trim().isEmpty
          ? null
          : _promoCodeController.text.trim().toUpperCase(),
      isActive: _isActive,
      views: widget.existingPost?.views ?? 0,
      likes: widget.existingPost?.likes ?? 0,
      shares: widget.existingPost?.shares ?? 0,
      createdAt: widget.existingPost?.createdAt ?? DateTime.now(),
    );

    widget.onSave(post);
    Navigator.pop(context);
  }
}
