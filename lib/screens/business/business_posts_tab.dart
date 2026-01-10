import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/business_model.dart';
import '../../models/business_post_model.dart';
import '../../services/business_service.dart';

/// Posts tab for sharing updates, products, promotions, and portfolio
class BusinessPostsTab extends StatefulWidget {
  final BusinessModel business;
  final VoidCallback onRefresh;

  const BusinessPostsTab({
    super.key,
    required this.business,
    required this.onRefresh,
  });

  @override
  State<BusinessPostsTab> createState() => _BusinessPostsTabState();
}

class _BusinessPostsTabState extends State<BusinessPostsTab> {
  final BusinessService _businessService = BusinessService();
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'icon': Icons.grid_view},
    {'label': 'Updates', 'icon': Icons.campaign},
    {'label': 'Products', 'icon': Icons.shopping_bag},
    {'label': 'Services', 'icon': Icons.build},
    {'label': 'Promotions', 'icon': Icons.local_offer},
    {'label': 'Portfolio', 'icon': Icons.photo_library},
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Posts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.analytics_outlined,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              // TODO: Show analytics
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildFilterChips(isDarkMode),
        ),
      ),
      body: StreamBuilder<List<BusinessPost>>(
        stream: _businessService.watchBusinessPosts(widget.business.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            );
          }

          final allPosts = snapshot.data ?? [];
          final posts = _filterPosts(allPosts);

          if (allPosts.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          if (posts.isEmpty) {
            return _buildNoResultsState(isDarkMode);
          }

          return RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            color: const Color(0xFF00D67D),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostCard(
                  post: post,
                  isDarkMode: isDarkMode,
                  onTap: () => _showPostDetails(post),
                  onEdit: () => _showEditSheet(post),
                  onDelete: () => _confirmDelete(post),
                  onToggleActive: () => _toggleActive(post),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(),
        backgroundColor: const Color(0xFF00D67D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Post'),
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter['label'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                filter['icon'] as IconData,
                size: 16,
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white54 : Colors.grey[600]),
              ),
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.lightImpact();
                setState(() => _selectedFilter = filter['label'] as String);
              },
              selectedColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF00D67D),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[100],
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF00D67D)
                    : (isDarkMode ? Colors.white24 : Colors.grey[300]!),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  List<BusinessPost> _filterPosts(List<BusinessPost> posts) {
    if (_selectedFilter == 'All') return posts;

    final filterMap = {
      'Updates': PostType.update,
      'Products': PostType.product,
      'Services': PostType.service,
      'Promotions': PostType.promotion,
      'Portfolio': PostType.portfolio,
    };

    final type = filterMap[_selectedFilter];
    if (type == null) return posts;

    return posts.where((p) => p.type == type).toList();
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
                Icons.post_add,
                size: 64,
                color: isDarkMode ? Colors.white24 : Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Posts Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share updates, products, services, and promotions with your customers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateSheet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D67D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedFilter posts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedFilter = 'All'),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet({PostType? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        business: widget.business,
        initialType: type,
        onSave: (post) async {
          final id = await _businessService.createPost(post);
          if (id != null && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post created successfully')),
            );
          }
        },
      ),
    );
  }

  void _showEditSheet(BusinessPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        business: widget.business,
        existingPost: post,
        onSave: (updatedPost) async {
          final success = await _businessService.updatePost(post.id, updatedPost);
          if (success && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post updated successfully')),
            );
          }
        },
      ),
    );
  }

  void _showPostDetails(BusinessPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PostDetailsSheet(post: post),
    );
  }

  void _confirmDelete(BusinessPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _businessService.deletePost(post.id);
              if (success && mounted) {
                widget.onRefresh();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleActive(BusinessPost post) async {
    final success = await _businessService.togglePostActive(post.id, !post.isActive);
    if (success && mounted) {
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(post.isActive ? 'Post hidden' : 'Post visible'),
        ),
      );
    }
  }
}

class _PostCard extends StatelessWidget {
  final BusinessPost post;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _PostCard({
    required this.post,
    required this.isDarkMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Type badge with icon
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.typeIcon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.typeName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getTypeColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!post.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hidden',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatDate(post.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'toggle':
                          onToggleActive();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              post.isActive ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(post.isActive ? 'Hide' : 'Show'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Image if present
            if (post.hasMedia)
              Container(
                height: 200,
                width: double.infinity,
                color: isDarkMode ? Colors.black26 : Colors.grey[100],
                child: post.images.isNotEmpty
                    ? Image.network(
                        post.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.title != null) ...[
                    Text(
                      post.title!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Price if applicable
                  if (post.price != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (post.hasDiscount) ...[
                          Text(
                            post.formattedOriginalPrice,
                            style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                              color: isDarkMode ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          post.formattedPrice,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00D67D),
                          ),
                        ),
                        if (post.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${post.calculatedDiscountPercent}% OFF',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Promo code if applicable
                  if (post.promoCode != null && post.type == PostType.promotion) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Code: ${post.promoCode}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Stats
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatItem(Icons.visibility, '${post.views}'),
                      const SizedBox(width: 16),
                      _buildStatItem(Icons.favorite_border, '${post.likes}'),
                      const SizedBox(width: 16),
                      _buildStatItem(Icons.share, '${post.shares}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.image,
        size: 48,
        color: isDarkMode ? Colors.white24 : Colors.grey[300],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDarkMode ? Colors.white38 : Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getTypeColor() {
    switch (post.type) {
      case PostType.update:
        return Colors.blue;
      case PostType.product:
        return Colors.teal;
      case PostType.service:
        return Colors.purple;
      case PostType.promotion:
        return Colors.orange;
      case PostType.portfolio:
        return Colors.pink;
      case PostType.location:
        return Colors.red;
      case PostType.hours:
        return Colors.indigo;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _CreatePostSheet extends StatefulWidget {
  final BusinessModel business;
  final PostType? initialType;
  final BusinessPost? existingPost;
  final Function(BusinessPost) onSave;

  const _CreatePostSheet({
    required this.business,
    this.initialType,
    this.existingPost,
    required this.onSave,
  });

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
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

class _PostDetailsSheet extends StatelessWidget {
  final BusinessPost post;

  const _PostDetailsSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTypeColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(post.typeIcon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          post.typeName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getTypeColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  if (post.title != null)
                    Text(
                      post.title!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      height: 1.6,
                    ),
                  ),

                  // Price
                  if (post.price != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (post.hasDiscount) ...[
                          Text(
                            post.formattedOriginalPrice,
                            style: TextStyle(
                              fontSize: 18,
                              decoration: TextDecoration.lineThrough,
                              color: isDarkMode ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          post.formattedPrice,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D67D),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Stats
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(Icons.visibility, '${post.views}', 'Views', isDarkMode),
                        _buildStatColumn(Icons.favorite, '${post.likes}', 'Likes', isDarkMode),
                        _buildStatColumn(Icons.share, '${post.shares}', 'Shares', isDarkMode),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String value, String label, bool isDarkMode) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00D67D), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getTypeColor() {
    switch (post.type) {
      case PostType.update:
        return Colors.blue;
      case PostType.product:
        return Colors.teal;
      case PostType.service:
        return Colors.purple;
      case PostType.promotion:
        return Colors.orange;
      case PostType.portfolio:
        return Colors.pink;
      case PostType.location:
        return Colors.red;
      case PostType.hours:
        return Colors.indigo;
    }
  }
}
