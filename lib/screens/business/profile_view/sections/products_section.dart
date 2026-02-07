import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/product_model.dart';
import '../../../../services/business_service.dart';
import '../../../../config/category_profile_config.dart';

/// Section displaying products for retail/grocery businesses
class ProductsSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final bool showCategories;
  final VoidCallback? onProductTap;

  const ProductsSection({
    super.key,
    required this.businessId,
    required this.config,
    this.showCategories = true,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<ProductCategoryModel>>(
      stream: BusinessService().watchProductCategories(businessId),
      builder: (context, categorySnapshot) {
        return StreamBuilder<List<ProductModel>>(
          stream: BusinessService().watchProducts(businessId),
          builder: (context, productSnapshot) {
            if (categorySnapshot.connectionState == ConnectionState.waiting ||
                productSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading(isDarkMode);
            }

            final categories = categorySnapshot.data ?? [];
            final products = productSnapshot.data ?? [];

            if (products.isEmpty) {
              return _buildEmptyState(isDarkMode);
            }

            // Group products by category
            final groupedProducts = <String, List<ProductModel>>{};
            for (final product in products) {
              final categoryId = product.categoryId;
              groupedProducts.putIfAbsent(categoryId, () => []);
              groupedProducts[categoryId]!.add(product);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(isDarkMode, products.length),
                if (showCategories && categories.isNotEmpty)
                  ...categories.map((category) {
                    final categoryProducts = groupedProducts[category.id] ?? [];
                    if (categoryProducts.isEmpty) return const SizedBox.shrink();
                    return _ProductCategorySection(
                      category: category,
                      products: categoryProducts,
                      config: config,
                      isDarkMode: isDarkMode,
                      onProductTap: onProductTap,
                    );
                  })
                else
                  _buildProductGrid(products, isDarkMode),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(bool isDarkMode, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            config.primarySectionIcon,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            config.primarySectionTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count items',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<ProductModel> products, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return ProductCard(
            product: products[index],
            config: config,
            isDarkMode: isDarkMode,
            onTap: onProductTap,
          );
        },
      ),
    );
  }

  Widget _buildLoading(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(
          color: config.primaryColor,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text(
              config.emptyStateIcon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              config.emptyStateMessage,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCategorySection extends StatelessWidget {
  final ProductCategoryModel category;
  final List<ProductModel> products;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onProductTap;

  const _ProductCategorySection({
    required this.category,
    required this.products,
    required this.config,
    required this.isDarkMode,
    this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${products.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 160,
                  child: ProductCard(
                    product: products[index],
                    config: config,
                    isDarkMode: isDarkMode,
                    onTap: onProductTap,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Card widget for displaying a product
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.config,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildProductImage(),
                  ),
                  // Out of stock overlay
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Out of Stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Discount badge
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Price
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: config.primaryColor,
                          ),
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white38 : Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    if (product.images.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: product.images.first,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _buildImagePlaceholder(),
        errorWidget: (context, url, error) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.shopping_bag,
          size: 40,
          color: config.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

}
