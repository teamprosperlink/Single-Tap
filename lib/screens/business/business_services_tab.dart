import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../models/business_post_model.dart';
import '../../res/config/dynamic_business_ui_config.dart' as dynamic_config;
import '../../services/business_service.dart';
import '../../widgets/business/business_widgets.dart';

/// Services/Products tab for managing business offerings
class BusinessServicesTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const BusinessServicesTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<BusinessServicesTab> createState() => _BusinessServicesTabState();
}

class _BusinessServicesTabState extends State<BusinessServicesTab>
    with SingleTickerProviderStateMixin {
  final BusinessService _businessService = BusinessService();
  late TabController _tabController;
  String _selectedFilter = 'All';
  late dynamic_config.CategoryTerminology _terminology;
  late List<String> _filters;
  bool _hasListings = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Get category-specific terminology
    if (widget.business.category != null) {
      _terminology = dynamic_config.CategoryTerminology.getForCategory(widget.business.category!);
      _filters = ['All', _terminology.filter1Label, _terminology.filter2Label];
    } else {
      _terminology = const dynamic_config.CategoryTerminology(
        screenTitle: 'Services & Products',
        filter1Label: 'Products',
        filter1Icon: 'shopping_bag',
        filter2Label: 'Services',
        filter2Icon: 'handyman',
        emptyStateMessage: 'Start adding products or services to showcase to your customers',
      );
      _filters = ['All', 'Products', 'Services'];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search listings...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(
                _terminology.screenTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildFilterChips(isDarkMode),
        ),
      ),
      body: StreamBuilder<List<BusinessListing>>(
        stream: _businessService.watchBusinessListings(widget.business.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            );
          }

          final allListings = snapshot.data ?? [];
          final listings = _filterListings(allListings);
          final hasAnyListings = allListings.isNotEmpty;
          final hasFilteredResults = listings.isNotEmpty;

          // Update state to control FAB visibility
          // Show FAB only when there are listings AND current filter shows results
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final shouldShowFAB = hasAnyListings && hasFilteredResults;
            if (_hasListings != shouldShowFAB) {
              setState(() {
                _hasListings = shouldShowFAB;
              });
            }
          });

          if (allListings.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          if (listings.isEmpty) {
            return _buildNoResultsState(isDarkMode);
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFF00D67D),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return _ServiceCard(
                  listing: listing,
                  isDarkMode: isDarkMode,
                  onTap: () => _showListingDetails(listing),
                  onEdit: () => _showEditSheet(listing),
                  onDelete: () => _confirmDelete(listing),
                  onToggleAvailability: () => _toggleAvailability(listing),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _hasListings
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSheet(),
              backgroundColor: const Color(0xFF00D67D),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
            )
          : null,
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: BusinessFilterBar(
        chips: _filters.map((filter) {
          IconData? icon;
          if (filter == _terminology.filter1Label) {
            icon = _terminology.getFilter1Icon();
          } else if (filter == _terminology.filter2Label) {
            icon = _terminology.getFilter2Icon();
          }

          return BusinessFilterChip(
            label: filter,
            isSelected: _selectedFilter == filter,
            onTap: () => setState(() => _selectedFilter = filter),
            icon: icon,
          );
        }).toList(),
      ),
    );
  }

  List<BusinessListing> _filterListings(List<BusinessListing> listings) {
    var filtered = listings;

    if (_selectedFilter != 'All') {
      if (_selectedFilter == _terminology.filter1Label) {
        filtered = filtered.where((l) => l.type == 'product').toList();
      } else {
        filtered = filtered.where((l) => l.type == 'service').toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((l) =>
        l.name.toLowerCase().contains(query) ||
        (l.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
                Icons.inventory_2_outlined,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Listings Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _terminology.emptyStateMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildDynamicAddButtons(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicAddButtons(bool isDarkMode) {
    // Get dynamic configuration based on business category
    if (widget.business.category == null) {
      return _buildDefaultAddButtons(isDarkMode);
    }

    final config = dynamic_config.DynamicUIConfig.getConfigForCategory(widget.business.category!);

    // Find relevant "add" actions from quick actions
    final addActions = config.quickActions.where((action) {
      return action == dynamic_config.QuickAction.addProduct ||
             action == dynamic_config.QuickAction.addService ||
             action == dynamic_config.QuickAction.addMenuItem ||
             action == dynamic_config.QuickAction.addRoom ||
             action == dynamic_config.QuickAction.addProperty ||
             action == dynamic_config.QuickAction.addVehicle ||
             action == dynamic_config.QuickAction.addCourse ||
             action == dynamic_config.QuickAction.addMembership ||
             action == dynamic_config.QuickAction.addPackage ||
             action == dynamic_config.QuickAction.addPortfolioItem;
    }).take(2).toList(); // Show max 2 buttons

    if (addActions.isEmpty) {
      return _buildDefaultAddButtons(isDarkMode);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: addActions.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        final isPrimary = index == 0;

        return Padding(
          padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
          child: isPrimary
              ? ElevatedButton.icon(
                  onPressed: () => _handleAddAction(action),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(action.label),
                )
              : OutlinedButton.icon(
                  onPressed: () => _handleAddAction(action),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D67D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    side: const BorderSide(color: Color(0xFF00D67D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(action.label),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildDefaultAddButtons(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showAddSheet(type: 'product'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D67D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _showAddSheet(type: 'service'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00D67D),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            side: const BorderSide(color: Color(0xFF00D67D)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Service'),
        ),
      ],
    );
  }

  void _handleAddAction(dynamic_config.QuickAction action) {
    String type;
    switch (action) {
      case dynamic_config.QuickAction.addMenuItem:
        type = 'menu_item';
        break;
      case dynamic_config.QuickAction.addProduct:
        type = 'product';
        break;
      case dynamic_config.QuickAction.addService:
        type = 'service';
        break;
      case dynamic_config.QuickAction.addRoom:
        type = 'room';
        break;
      case dynamic_config.QuickAction.addProperty:
        type = 'property';
        break;
      case dynamic_config.QuickAction.addVehicle:
        type = 'vehicle';
        break;
      case dynamic_config.QuickAction.addCourse:
        type = 'course';
        break;
      case dynamic_config.QuickAction.addMembership:
        type = 'membership';
        break;
      case dynamic_config.QuickAction.addPackage:
        type = 'package';
        break;
      case dynamic_config.QuickAction.addPortfolioItem:
        type = 'portfolio';
        break;
      default:
        type = 'service';
    }
    _showAddSheet(type: type);
  }

  Widget _buildNoResultsState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
                Icons.add_circle_outline,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No $_selectedFilter Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ${_selectedFilter.toLowerCase()} to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddSheet(),
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
              label: Text('Add ${_selectedFilter == 'All' ? 'New' : _selectedFilter}'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _selectedFilter = 'All'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00D67D),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet({String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddServiceSheet(
        businessId: widget.business.id,
        business: widget.business,
        initialType: type,
        onSave: (listing) async {
          final id = await _businessService.createListing(listing);
          if (id != null && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            final typeLabel = listing.type == 'product' ? _terminology.filter1Label : _terminology.filter2Label;
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(content: Text('$typeLabel added successfully')),
            );
          }
        },
      ),
    );
  }

  void _showEditSheet(BusinessListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddServiceSheet(
        businessId: widget.business.id,
        business: widget.business,
        existingListing: listing,
        onSave: (updatedListing) async {
          final success = await _businessService.updateListing(listing.id, updatedListing);
          if (success && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('Listing updated successfully')),
            );
          }
        },
      ),
    );
  }

  void _showListingDetails(BusinessListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ListingDetailsSheet(listing: listing),
    );
  }

  void _confirmDelete(BusinessListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Listing?'),
        content: Text(
          'Are you sure you want to delete "${listing.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _businessService.deleteListing(widget.business.id, listing.id);
              if (success && mounted) {
                widget.onRefresh();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Listing deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleAvailability(BusinessListing listing) async {
    final success = await _businessService.toggleListingAvailability(
      widget.business.id,
      listing.id,
      !listing.isAvailable,
    );
    if (success && mounted) {
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listing.isAvailable ? 'Marked as unavailable' : 'Marked as available',
          ),
        ),
      );
    }
  }
}

class _ServiceCard extends StatelessWidget {
  final BusinessListing listing;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _ServiceCard({
    required this.listing,
    required this.isDarkMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final isProduct = listing.type == 'product';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Image or placeholder
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isProduct
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: listing.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            listing.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholderIcon(isProduct),
                          ),
                        )
                      : _buildPlaceholderIcon(isProduct),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isProduct
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isProduct ? 'Product' : 'Service',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isProduct ? Colors.blue : Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (listing.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          listing.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            listing.formattedPrice,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00D67D),
                            ),
                          ),
                          const Spacer(),
                          listing.isAvailable
                              ? StatusBadge.available(showIcon: true)
                              : StatusBadge.inactive(showIcon: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: Colors.blue,
                  onTap: onEdit,
                ),
                _buildActionChip(
                  icon: listing.isAvailable ? Icons.visibility_off : Icons.visibility,
                  label: listing.isAvailable ? 'Hide' : 'Show',
                  color: Colors.orange,
                  onTap: onToggleAvailability,
                ),
                _buildActionChip(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(bool isProduct) {
    return Icon(
      isProduct ? Icons.shopping_bag_outlined : Icons.handyman_outlined,
      size: 32,
      color: isProduct ? Colors.blue : Colors.purple,
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddServiceSheet extends StatefulWidget {
  final String businessId;
  final String? initialType;
  final BusinessListing? existingListing;
  final Function(BusinessListing) onSave;
  final BusinessModel business;

  const _AddServiceSheet({
    required this.businessId,
    this.initialType,
    this.existingListing,
    required this.onSave,
    required this.business,
  });

  @override
  State<_AddServiceSheet> createState() => _AddServiceSheetState();
}

class _AddServiceSheetState extends State<_AddServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  late String _selectedType;
  String _selectedPricingType = PricingTypes.fixed;
  bool _isAvailable = true;
  bool _isSaving = false;
  late dynamic_config.CategoryTerminology _terminology;

  @override
  void initState() {
    super.initState();

    // Get category-specific terminology
    if (widget.business.category != null) {
      _terminology = dynamic_config.CategoryTerminology.getForCategory(widget.business.category!);
    } else {
      _terminology = const dynamic_config.CategoryTerminology(
        screenTitle: 'Services & Products',
        filter1Label: 'Products',
        filter1Icon: 'shopping_bag',
        filter2Label: 'Services',
        filter2Icon: 'handyman',
        emptyStateMessage: 'Start adding products or services to showcase to your customers',
      );
    }

    _selectedType = widget.existingListing?.type ?? widget.initialType ?? 'product';

    if (widget.existingListing != null) {
      _nameController.text = widget.existingListing!.name;
      _descriptionController.text = widget.existingListing!.description ?? '';
      _priceController.text = widget.existingListing!.price?.toString() ?? '';
      _isAvailable = widget.existingListing!.isAvailable;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingListing != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit' : _terminology.screenTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isEditing
                      ? 'Update ${_selectedType == 'product' ? _terminology.filter1Label.toLowerCase() : _terminology.filter2Label.toLowerCase()} details'
                      : 'Choose type and fill in the details',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Selection
                    Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeOption(
                            type: 'product',
                            icon: _terminology.getFilter1Icon(),
                            label: _terminology.filter1Label,
                            color: Colors.blue,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeOption(
                            type: 'service',
                            icon: _terminology.getFilter2Icon(),
                            label: _terminology.filter2Label,
                            color: Colors.purple,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter ${_selectedType == 'product' ? _terminology.filter1Label.toLowerCase() : _terminology.filter2Label.toLowerCase()} name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your ${_selectedType == 'product' ? _terminology.filter1Label.toLowerCase() : _terminology.filter2Label.toLowerCase()}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pricing Type
                    Text(
                      'Pricing Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PricingTypes.all.map((type) {
                        final isSelected = _selectedPricingType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedPricingType = type);
                            }
                          },
                          selectedColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF00D67D),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Price
                    if (_selectedPricingType != PricingTypes.negotiable &&
                        _selectedPricingType != PricingTypes.free)
                      TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price',
                          hintText: '0',
                          prefixText: '\u{20B9} ',
                          suffixText: _selectedPricingType == PricingTypes.hourly
                              ? '/hr'
                              : (_selectedPricingType == PricingTypes.perUnit ? '/unit' : null),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Availability
                    SwitchListTile(
                      title: Text(
                        'Available',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _isAvailable
                            ? 'Customers can see this listing'
                            : 'Hidden from customers',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      value: _isAvailable,
                      onChanged: (value) => setState(() => _isAvailable = value),
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
          // Save button
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
                          isEditing ? 'Save Changes' : 'Add Listing',
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

  Widget _buildTypeOption({
    required String type,
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedType = type);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
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
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final price = double.tryParse(_priceController.text);

    final listing = BusinessListing(
      id: widget.existingListing?.id ?? '',
      businessId: widget.businessId,
      type: _selectedType,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: _selectedPricingType == PricingTypes.free ? 0 : price,
      currency: 'INR',
      isAvailable: _isAvailable,
      createdAt: widget.existingListing?.createdAt ?? DateTime.now(),
    );

    widget.onSave(listing);
    Navigator.pop(context);
  }
}

class _ListingDetailsSheet extends StatelessWidget {
  final BusinessListing listing;

  const _ListingDetailsSheet({required this.listing});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isProduct = listing.type == 'product';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isProduct
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: listing.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              listing.images.first,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            isProduct ? Icons.shopping_bag : Icons.handyman,
                            size: 64,
                            color: isProduct ? Colors.blue : Colors.purple,
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isProduct
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isProduct ? 'Product' : 'Service',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isProduct ? Colors.blue : Colors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Text(
                    listing.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Text(
                    listing.formattedPrice,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D67D),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Availability
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: listing.isAvailable
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              listing.isAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: listing.isAvailable ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              listing.isAvailable ? 'Available' : 'Unavailable',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: listing.isAvailable ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (listing.description != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      listing.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
