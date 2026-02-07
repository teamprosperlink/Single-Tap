import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product_model.dart';
import '../../../models/business_model.dart';
import '../../../services/business_service.dart';
import 'add_product_wizard.dart';
import 'product_category_screen.dart';

/// Tab for managing retail products
class ProductsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback? onRefresh;

  const ProductsTab({
    super.key,
    required this.business,
    this.onRefresh,
  });

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final BusinessService _businessService = BusinessService();
  String? _selectedCategoryId;
  String _filterType = 'all'; // all, inStock, outOfStock, featured

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDarkMode),
            _buildCategoryTabs(isDarkMode),
            _buildFilterChips(isDarkMode),
            Expanded(child: _buildProductsList(isDarkMode)),
          ],
        ),
      ),
      floatingActionButton: StreamBuilder<List<ProductModel>>(
        stream: _businessService.watchProducts(widget.business.id),
        builder: (context, snapshot) {
          final hasProducts = (snapshot.data ?? []).isNotEmpty;

          // Only show FAB if there are products (empty state has its own button)
          if (!hasProducts) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _addProduct,
            backgroundColor: const Color(0xFF00D67D),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Product',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D67D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF00D67D),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Manage your inventory',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _manageCategories,
            icon: Icon(
              Icons.category_outlined,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
            tooltip: 'Manage Categories',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDarkMode) {
    return StreamBuilder<List<ProductCategoryModel>>(
      stream: _businessService.watchProductCategories(widget.business.id),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                Icon(
                  Icons.info_outline,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create categories to organize your products',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _manageCategories,
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Color(0xFF00D67D)),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: _selectedCategoryId == null,
                onTap: () => setState(() => _selectedCategoryId = null),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 8),
              ...categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CategoryChip(
                    label: category.name,
                    isSelected: _selectedCategoryId == category.id,
                    onTap: () => setState(() => _selectedCategoryId = category.id),
                    isDarkMode: isDarkMode,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: _filterType == 'all',
              onTap: () => setState(() => _filterType = 'all'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'In Stock',
              isSelected: _filterType == 'inStock',
              onTap: () => setState(() => _filterType = 'inStock'),
              isDarkMode: isDarkMode,
              iconData: Icons.check_circle_outline,
              iconColor: Colors.green,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Out of Stock',
              isSelected: _filterType == 'outOfStock',
              onTap: () => setState(() => _filterType = 'outOfStock'),
              isDarkMode: isDarkMode,
              iconData: Icons.cancel_outlined,
              iconColor: Colors.red,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Featured',
              isSelected: _filterType == 'featured',
              onTap: () => setState(() => _filterType = 'featured'),
              isDarkMode: isDarkMode,
              iconData: Icons.star_outline,
              iconColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(bool isDarkMode) {
    return StreamBuilder<List<ProductModel>>(
      stream: _businessService.watchProducts(
        widget.business.id,
        categoryId: _selectedCategoryId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: isDarkMode ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading products',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final allProducts = snapshot.data ?? [];
        final products = _filterProducts(allProducts);

        if (products.isEmpty) {
          return _buildEmptyState(isDarkMode, allProducts.isEmpty);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductCard(
              product: product,
              isDarkMode: isDarkMode,
              onTap: () => _editProduct(product),
              onToggleStock: () => _toggleStock(product),
              onDelete: () => _deleteProduct(product),
            );
          },
        );
      },
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    switch (_filterType) {
      case 'inStock':
        return products.where((p) => p.inStock && p.stock > 0).toList();
      case 'outOfStock':
        return products.where((p) => !p.inStock || p.stock == 0).toList();
      case 'featured':
        return products.where((p) => p.isFeatured).toList();
      default:
        return products;
    }
  }

  Widget _buildEmptyState(bool isDarkMode, bool noProductsAtAll) {
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
              noProductsAtAll ? Icons.inventory_2_rounded : Icons.search_off_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            noProductsAtAll ? 'No Products Yet' : 'No Matching Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noProductsAtAll
                ? 'Add your first product to get started'
                : 'Try a different filter or category',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          if (noProductsAtAll) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ],
      ),
    );
  }

  void _addProduct() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductWizard(
          business: widget.business,
        ),
      ),
    ).then((result) {
      if (result == true) {
        widget.onRefresh?.call();
      }
    });
  }

  void _editProduct(ProductModel product) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductWizard(
          business: widget.business,
          existingItem: product,
        ),
      ),
    ).then((result) {
      if (result == true) {
        widget.onRefresh?.call();
      }
    });
  }

  void _manageCategories() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCategoryScreen(
          businessId: widget.business.id,
        ),
      ),
    );
  }

  Future<void> _toggleStock(ProductModel product) async {
    HapticFeedback.lightImpact();
    final updatedProduct = product.copyWith(inStock: !product.inStock);
    await _businessService.updateProduct(widget.business.id, product.id, updatedProduct);
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
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
      await _businessService.deleteProduct(widget.business.id, product.id, product.categoryId);
      widget.onRefresh?.call();
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDarkMode;
  final IconData? iconData;
  final Color? iconColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    this.iconData,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : (isDarkMode ? const Color(0xFF2D2D44) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D67D)
                : (isDarkMode ? Colors.white12 : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(
                iconData,
                size: 14,
                color: isSelected ? const Color(0xFF00D67D) : iconColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onToggleStock;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.isDarkMode,
    required this.onTap,
    required this.onToggleStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      image: product.images.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(product.images.first),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.images.isEmpty
                        ? const Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Color(0xFF00D67D),
                          )
                        : null,
                  ),
                  // Stock badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: product.inStock && product.stock > 0
                            ? Colors.green
                            : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.inStock && product.stock > 0
                            ? 'In Stock'
                            : 'Out of Stock',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Featured badge
                  if (product.isFeatured)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // Price
                      Row(
                        children: [
                          Text(
                            product.formattedPrice,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D67D),
                            ),
                          ),
                          if (product.hasDiscount &&
                              product.formattedOriginalPrice != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              product.formattedOriginalPrice!,
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Stock count
                      Text(
                        'Stock: ${product.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
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
