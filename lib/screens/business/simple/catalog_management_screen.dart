import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _CatalogManagementScreenState extends State<CatalogManagementScreen>
    with SingleTickerProviderStateMixin {
  final _catalogService = CatalogService();
  final _searchController = TextEditingController();
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  String _searchQuery = '';
  CatalogItemType? _filterType; // null = All
  bool _isGridView = false;
  bool _hasItems = false;

  late final AnimationController _fabController;
  late final CurvedAnimation _fabAnimation;
  late final ScrollController _scrollController;
  bool _isFabExpanded = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  void _onScroll() {
    final dir = _scrollController.position.userScrollDirection;
    if (dir == ScrollDirection.reverse && _isFabExpanded) {
      setState(() => _isFabExpanded = false);
      _fabController.reverse();
    } else if (dir == ScrollDirection.forward && !_isFabExpanded) {
      setState(() => _isFabExpanded = true);
      _fabController.forward();
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    _fabAnimation.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CatalogItemForm()),
    );
  }

  Widget _buildAnimatedFab() {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, _) {
        final t = _fabAnimation.value;
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addItem,
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    SizedBox(
                      width: 110 * t,
                      child: Opacity(
                        opacity: (t * 2).clamp(0.0, 1.0),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            'Add Item',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: textColor),
                title: Text('Edit', style: TextStyle(color: textColor)),
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
                  color: textColor,
                ),
                title: Text(
                  item.isAvailable ? 'Mark Sold Out' : 'Mark Available',
                  style: TextStyle(color: textColor),
                ),
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
                    builder: (ctx) {
                      final dlgTextColor = isDark ? Colors.white : Colors.black;
                      return AlertDialog(
                        backgroundColor:
                            isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text('Delete Item',
                            style: TextStyle(color: dlgTextColor)),
                        content: Text('Delete "${item.name}"?',
                            style: TextStyle(
                                color: dlgTextColor.withValues(alpha: 0.7))),
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
                      );
                    },
                  );
                  if (confirm == true && _userId != null) {
                    await _catalogService.deleteItem(_userId!, item.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<CatalogItem> _applyFilters(List<CatalogItem> items) {
    return items.where((item) {
      if (_filterType != null && item.type != _filterType) return false;
      if (_searchQuery.isNotEmpty &&
          !item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

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
        title: const Text('My Catalog',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 22,
            ),
            tooltip: _isGridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      floatingActionButton: _hasItems ? _buildAnimatedFab() : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: subtitleColor, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: subtitleColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: subtitleColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _filterChip('All', _filterType == null, () {
                  setState(() => _filterType = null);
                }, isDark),
                const SizedBox(width: 8),
                _filterChip(
                    'Products', _filterType == CatalogItemType.product, () {
                  setState(() => _filterType = CatalogItemType.product);
                }, isDark),
                const SizedBox(width: 8),
                _filterChip(
                    'Services', _filterType == CatalogItemType.service, () {
                  setState(() => _filterType = CatalogItemType.service);
                }, isDark),
              ],
            ),
          ),

          // Catalog list/grid
          Expanded(
            child: StreamBuilder<List<CatalogItem>>(
              stream: _catalogService.streamCatalog(_userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allItems = snapshot.data ?? [];
                final items = _applyFilters(allItems);

                // Update FAB visibility after frame
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _hasItems != allItems.isNotEmpty) {
                    setState(() => _hasItems = allItems.isNotEmpty);
                  }
                });

                if (allItems.isEmpty) {
                  return _buildEmptyState(isDark, textColor, subtitleColor);
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: subtitleColor),
                        const SizedBox(height: 12),
                        Text(
                          'No items match your search',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (_isGridView) {
                  return GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
                  );
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildListItem(
                        item, isDark, textColor, subtitleColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Chip ──

  Widget _filterChip(
      String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── List Item Row ──

  Widget _buildListItem(
    CatalogItem item,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    // Build subtitle text
    String subtitle = '';
    if (item.type == CatalogItemType.service && item.formattedDuration != null) {
      subtitle = 'Duration: ${item.formattedDuration}';
    } else if (item.category != null && item.category!.isNotEmpty) {
      subtitle = item.category!;
    } else {
      switch (item.type) {
        case CatalogItemType.service:
          subtitle = 'Service';
        case CatalogItemType.product:
          subtitle = 'Product';
      }
    }

    return GestureDetector(
      onTap: () => _editItem(item),
      onLongPress: () => _showItemOptions(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Item image/icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.allImages.isNotEmpty
                  ? Image.network(
                      item.allImages.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _itemIcon(item, isDark),
                    )
                  : _itemIcon(item, isDark),
            ),
            const SizedBox(width: 12),

            // Name + subtitle + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            _statusBadge(item.isAvailable, isDark),
            const SizedBox(width: 4),

            // 3-dot menu
            GestureDetector(
              onTap: () => _showItemOptions(item),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.more_horiz,
                  color: subtitleColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemIcon(CatalogItem item, bool isDark) {
    IconData icon;
    switch (item.type) {
      case CatalogItemType.service:
        icon = Icons.build_outlined;
      case CatalogItemType.product:
        icon = Icons.shopping_bag_outlined;
    }
    return Center(
      child: Icon(icon,
          size: 24,
          color: const Color(0xFF3B82F6).withValues(alpha: 0.8)),
    );
  }

  Widget _statusBadge(bool isAvailable, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable
            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAvailable ? 'Active' : 'Sold Out',
        style: TextStyle(
          color: isAvailable ? const Color(0xFF22C55E) : Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Empty State ──

  Widget _buildEmptyState(bool isDark, Color textColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.storefront_outlined,
                size: 36,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.2)),
          ),
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
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
