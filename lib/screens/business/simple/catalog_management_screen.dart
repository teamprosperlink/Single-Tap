import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/catalog_item.dart';
import '../../../services/catalog_service.dart';
import '../../../widgets/catalog_card_widget.dart';
import 'catalog_item_form.dart';

class CatalogManagementScreen extends StatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  State<CatalogManagementScreen> createState() =>
      _CatalogManagementScreenState();
}

class _CatalogManagementScreenState extends State<CatalogManagementScreen> {
  final _catalogService = CatalogService();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CatalogItemForm()),
    );
  }

  void _editItem(CatalogItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CatalogItemForm(item: item)),
    );
  }

  void _showItemOptions(CatalogItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _editItem(item);
              },
            ),
            ListTile(
              leading: Icon(
                item.isAvailable
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              title: Text(item.isAvailable
                  ? 'Mark Unavailable'
                  : 'Mark Available'),
              onTap: () async {
                Navigator.pop(ctx);
                await _catalogService.toggleAvailability(
                  item.userId,
                  item.id,
                  !item.isAvailable,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: Text('Delete "${item.name}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && _userId != null) {
                  await _catalogService.deleteItem(_userId!, item.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('My Catalog')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('My Catalog'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: const Color(0xFF22C55E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<CatalogItem>>(
        stream: _catalogService.streamCatalog(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 64,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'No items yet',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first product or service',
                    style: TextStyle(color: subtitleColor, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${items.length} / ${CatalogService.maxItems} items',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CatalogCardWidget(
                      item: item,
                      onTap: () => _editItem(item),
                      onLongPress: () => _showItemOptions(item),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
