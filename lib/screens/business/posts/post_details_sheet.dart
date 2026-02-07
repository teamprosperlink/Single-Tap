import 'package:flutter/material.dart';
import '../../../models/business_post_model.dart';

/// Bottom sheet for displaying detailed view of a business post
class PostDetailsSheet extends StatelessWidget {
  final BusinessPost post;

  const PostDetailsSheet({
    super.key,
    required this.post,
  });

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
