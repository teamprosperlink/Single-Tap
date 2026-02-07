import '../../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../models/business_model.dart';
import '../../../../models/product_model.dart';

/// Inventory Management Tab for Retail Archetype
/// Track stock levels, low stock alerts, and stock adjustments
class InventoryTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const InventoryTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final FirebaseFirestore _firestore = FirebaseProvider.firestore;
  String _filterMode = 'all'; // 'all', 'low_stock', 'out_of_stock'

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  Row(
                    children: [
                      _buildFilterChip(
                        label: 'All Products',
                        value: 'all',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Low Stock',
                        value: 'low_stock',
                        isDarkMode: isDarkMode,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Out of Stock',
                        value: 'out_of_stock',
                        isDarkMode: isDarkMode,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Inventory Stats
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('businesses')
                .doc(widget.business.id)
                .collection('products')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final products = snapshot.data!.docs
                  .map((doc) => ProductModel.fromFirestore(doc))
                  .toList();

              final lowStock = products
                  .where((p) => p.stock > 0 && p.stock < 10)
                  .length;
              final outOfStock = products.where((p) => p.stock == 0).length;

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.inventory_2,
                        label: 'Total Items',
                        value: '${products.length}',
                        color: const Color(0xFF10B981),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.warning_amber,
                        label: 'Low Stock',
                        value: '$lowStock',
                        color: const Color(0xFFF59E0B),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.remove_circle,
                        label: 'Out of Stock',
                        value: '$outOfStock',
                        color: const Color(0xFFEF4444),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Product List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('businesses')
                  .doc(widget.business.id)
                  .collection('products')
                  .snapshots(),
              builder: (context, snapshot) {
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
                          'Error loading inventory',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D67D)),
                  );
                }

                var products = snapshot.data!.docs
                    .map((doc) => ProductModel.fromFirestore(doc))
                    .toList();

                // Apply filter
                switch (_filterMode) {
                  case 'low_stock':
                    products = products
                        .where((p) => p.stock > 0 && p.stock < 10)
                        .toList();
                    break;
                  case 'out_of_stock':
                    products = products.where((p) => p.stock == 0).toList();
                    break;
                  default:
                    break;
                }

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _filterMode == 'out_of_stock'
                              ? Icons.check_circle_outline
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: isDarkMode ? Colors.white24 : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filterMode == 'low_stock'
                              ? 'No low stock items'
                              : _filterMode == 'out_of_stock'
                              ? 'No out of stock items'
                              : 'No products yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    widget.onRefresh();
                  },
                  color: const Color(0xFF00D67D),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildInventoryCard(products[index], isDarkMode);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isDarkMode,
    Color? color,
  }) {
    final isSelected = _filterMode == value;
    final chipColor = color ?? const Color(0xFF10B981);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterMode = value);
      },
      backgroundColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey[100],
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDarkMode ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(color: isSelected ? chipColor : Colors.transparent),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryCard(ProductModel product, bool isDarkMode) {
    final stockStatus = product.stock == 0
        ? 'Out of Stock'
        : product.stock < 10
        ? 'Low Stock'
        : 'In Stock';

    final statusColor = product.stock == 0
        ? const Color(0xFFEF4444)
        : product.stock < 10
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.inventory_2,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Product Details
          Expanded(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'SKU: ${product.sku ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stockStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stock Controls
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stock}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'units',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStockButton(
                    icon: Icons.remove,
                    onTap: () => _updateStock(product, -1),
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildStockButton(
                    icon: Icons.add,
                    onTap: () => _updateStock(product, 1),
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildStockButton(
                    icon: Icons.edit,
                    onTap: () => _showStockEditDialog(product),
                    isDarkMode: isDarkMode,
                    color: const Color(0xFF3B82F6),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDarkMode,
    Color? color,
  }) {
    final buttonColor = color ?? const Color(0xFF10B981);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: buttonColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: buttonColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 16, color: buttonColor),
      ),
    );
  }

  Future<void> _updateStock(ProductModel product, int change) async {
    final newStock = (product.stock + change).clamp(0, 999999);

    try {
      await _firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('products')
          .doc(product.id)
          .update({'stock': newStock});

      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStockEditDialog(ProductModel product) async {
    final controller = TextEditingController(text: product.stock.toString());
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          title: Text(
            'Update Stock',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
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
                final newStock = int.tryParse(controller.text) ?? product.stock;
                Navigator.pop(context);

                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _firestore
                      .collection('businesses')
                      .doc(widget.business.id)
                      .collection('products')
                      .doc(product.id)
                      .update({'stock': newStock});

                  widget.onRefresh();
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to update stock: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
