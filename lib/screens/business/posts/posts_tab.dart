import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/business_model.dart';
import '../../../models/business_post_model.dart';
import '../../../services/business_service.dart';
import 'post_card.dart';
import 'create_post_sheet.dart';
import 'post_details_sheet.dart';

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
                return PostCard(
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
      builder: (context) => CreatePostSheet(
        business: widget.business,
        initialType: type,
        onSave: (post) async {
          final id = await _businessService.createPost(post);
          if (id != null && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
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
      builder: (context) => CreatePostSheet(
        business: widget.business,
        existingPost: post,
        onSave: (updatedPost) async {
          final success = await _businessService.updatePost(post.id, updatedPost);
          if (success && mounted) {
            widget.onRefresh();
            if (!mounted) return;
            ScaffoldMessenger.of(this.context).showSnackBar(
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
      builder: (context) => PostDetailsSheet(post: post),
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
              final success = await _businessService.deletePost(widget.business.id, post.id);
              if (success && mounted) {
                widget.onRefresh();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
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
    final success = await _businessService.togglePostActive(widget.business.id, post.id, !post.isActive);
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
