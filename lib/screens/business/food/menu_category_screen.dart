import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/menu_model.dart';
import '../../../services/business_service.dart';

/// Screen for managing menu categories
class MenuCategoryScreen extends StatefulWidget {
  final String businessId;

  const MenuCategoryScreen({
    super.key,
    required this.businessId,
  });

  @override
  State<MenuCategoryScreen> createState() => _MenuCategoryScreenState();
}

class _MenuCategoryScreenState extends State<MenuCategoryScreen> {
  final BusinessService _businessService = BusinessService();

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
          'Menu Categories',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddCategoryDialog(context, isDarkMode),
            icon: const Icon(
              Icons.add,
              color: Color(0xFF00D67D),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<MenuCategoryModel>>(
        stream: _businessService.watchMenuCategories(widget.businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            );
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) => _reorderCategories(
              categories,
              oldIndex,
              newIndex,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(
                key: ValueKey(category.id),
                category: category,
                isDarkMode: isDarkMode,
                onEdit: () => _showEditCategoryDialog(context, isDarkMode, category),
                onDelete: () => _deleteCategory(category),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, isDarkMode),
        backgroundColor: const Color(0xFF00D67D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Category',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_outlined,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Categories Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create categories to organize your menu items',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildQuickAddSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildQuickAddSection(bool isDarkMode) {
    return Column(
      children: [
        Text(
          'Quick Add',
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
          alignment: WrapAlignment.center,
          children: DefaultMenuCategories.restaurant.map((name) {
            return GestureDetector(
              onTap: () => _quickAddCategory(name),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDarkMode ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: const Color(0xFF00D67D),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
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
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context, bool isDarkMode) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedCategory;
    bool showCustomField = false;

    // Combine all default categories
    final allCategories = [
      ...DefaultMenuCategories.restaurant,
      ...DefaultMenuCategories.cafe.where(
        (c) => !DefaultMenuCategories.restaurant.contains(c),
      ),
      'Custom',
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          title: Text(
            'Add Category',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown for category selection
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00D67D),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    hint: Text(
                      'Select Category',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    items: allCategories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value;
                        showCustomField = value == 'Custom';
                        if (!showCustomField && value != null) {
                          nameController.text = value;
                        } else if (showCustomField) {
                          nameController.clear();
                        }
                      });
                    },
                  ),
                ),
              ),
              // Custom name field (shown when "Custom" is selected)
              if (showCustomField) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Custom Category Name',
                    hintText: 'Enter category name',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00D67D)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00D67D)),
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
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await _addCategory(name, descController.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCategoryDialog(
    BuildContext context,
    bool isDarkMode,
    MenuCategoryModel category,
  ) async {
    final nameController = TextEditingController(text: category.name);
    final descController = TextEditingController(text: category.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: Text(
          'Edit Category',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Category Name',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D67D)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D67D)),
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
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await _updateCategory(
                category,
                nameController.text.trim(),
                descController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCategory(String name, String description) async {
    try {
      final categories = await _businessService.getMenuCategories(widget.businessId);
      final category = MenuCategoryModel(
        id: '',
        businessId: widget.businessId,
        name: name,
        description: description.isEmpty ? null : description,
        sortOrder: categories.length,
      );
      await _businessService.createMenuCategory(category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quickAddCategory(String name) async {
    HapticFeedback.lightImpact();
    await _addCategory(name, '');
  }

  Future<void> _updateCategory(
    MenuCategoryModel category,
    String name,
    String description,
  ) async {
    try {
      final updated = category.copyWith(
        name: name,
        description: description.isEmpty ? null : description,
      );
      await _businessService.updateMenuCategory(
        widget.businessId,
        category.id,
        updated,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(MenuCategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? '
          'Items in this category will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _businessService.deleteMenuCategory(widget.businessId, category.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reorderCategories(
    List<MenuCategoryModel> categories,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;

    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    // Update sort orders
    for (int i = 0; i < categories.length; i++) {
      final updated = categories[i].copyWith(sortOrder: i);
      await _businessService.updateMenuCategory(
        widget.businessId,
        categories[i].id,
        updated,
      );
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final MenuCategoryModel category;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00D67D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.restaurant_menu,
            color: Color(0xFF00D67D),
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: category.description != null
            ? Text(
                category.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: onDelete,
            ),
            Icon(
              Icons.drag_handle,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
