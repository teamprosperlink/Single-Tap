import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_profile.dart';
import '../../../models/catalog_item.dart';
import '../../../services/catalog_service.dart';
import '../../../widgets/catalog_card_widget.dart';
import 'business_setup_flow.dart';
import 'business_info_edit.dart';
import 'business_hours_edit.dart';
import 'catalog_item_form.dart';

class BusinessHubScreen extends StatefulWidget {
  const BusinessHubScreen({super.key});

  @override
  State<BusinessHubScreen> createState() => _BusinessHubScreenState();
}

class _BusinessHubScreenState extends State<BusinessHubScreen> {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title:
                  const Text('Edit', style: TextStyle(color: Colors.white)),
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
                color: Colors.white,
              ),
              title: Text(
                item.isAvailable ? 'Mark Unavailable' : 'Mark Available',
                style: const TextStyle(color: Colors.white),
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
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Delete Item',
                        style: TextStyle(color: Colors.white)),
                    content: Text('Delete "${item.name}"?',
                        style: const TextStyle(color: Colors.white70)),
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
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Please sign in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final isBusiness =
            AccountType.fromString(userData?['accountType']) ==
                AccountType.business;

        if (!isBusiness) {
          return _buildEnableBusinessView();
        }

        final bp = userData?['businessProfile'] != null
            ? BusinessProfile.fromMap(
                Map<String, dynamic>.from(userData!['businessProfile']))
            : BusinessProfile();

        return _buildBusinessView(bp);
      },
    );
  }

  // ── Non-business users: prompt to enable ──

  Widget _buildEnableBusinessView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Business'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.storefront_rounded,
                    size: 40, color: Color(0xFF22C55E)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Enable Business Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add products, services, and a catalog to your profile. Customers can browse and enquire directly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BusinessSetupFlow()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Get Started',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Business users: full hub ──

  Widget _buildBusinessView(BusinessProfile bp) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Business'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: const Color(0xFF22C55E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          // Business header + stats + actions
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildBusinessHeader(bp),
                const SizedBox(height: 12),
                _buildStatsRow(bp),
                const SizedBox(height: 12),
                _buildQuickActions(bp),
                const SizedBox(height: 16),
                // Catalog section title
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'My Catalog',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder<List<CatalogItem>>(
                        stream: _catalogService.streamCatalog(_userId!),
                        builder: (context, snap) {
                          final count = snap.data?.length ?? 0;
                          return Text(
                            '$count / ${CatalogService.maxItems}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Catalog grid
          _buildCatalogGrid(),
        ],
      ),
    );
  }

  Widget _buildBusinessHeader(BusinessProfile bp) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Business icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Color(0xFF22C55E), size: 24),
          ),
          const SizedBox(width: 14),
          // Name + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bp.businessName ?? 'My Business',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bp.softLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bp.softLabel!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Open/Closed badge
          if (bp.hours != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bp.isCurrentlyOpen
                    ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bp.isCurrentlyOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  color: bp.isCurrentlyOpen
                      ? const Color(0xFF22C55E)
                      : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BusinessProfile bp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard('Profile Views', bp.profileViews),
          const SizedBox(width: 10),
          _statCard('Catalog Views', bp.catalogViews),
          const SizedBox(width: 10),
          _statCard('Enquiries', bp.enquiryCount),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BusinessProfile bp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _actionButton(
            icon: Icons.edit_outlined,
            label: 'Edit Info',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessInfoEdit(businessProfile: bp),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _actionButton(
            icon: Icons.access_time,
            label: 'Hours',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessHoursEdit(
                    hours: bp.hours ?? BusinessHours.defaultHours(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _actionButton(
            icon: Icons.add_circle_outline,
            label: 'Add Item',
            color: const Color(0xFF22C55E),
            onTap: _addItem,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogGrid() {
    if (_userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<List<CatalogItem>>(
      stream: _catalogService.streamCatalog(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(height: 16),
                  const Text(
                    'No items yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first product or service',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
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
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return CatalogCardWidget(
                  item: item,
                  onTap: () => _editItem(item),
                  onLongPress: () => _showItemOptions(item),
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}
