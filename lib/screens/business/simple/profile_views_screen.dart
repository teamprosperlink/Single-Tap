import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileViewsScreen extends StatelessWidget {
  const ProfileViewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final _userId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    if (_userId == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Profile Views')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Profile Views',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>?;
          final bpMap =
              userData?['businessProfile'] as Map<String, dynamic>?;
          final counterViews = bpMap?['profileViews'] as int? ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .collection('profileViews')
                .orderBy('viewedAt', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  userSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('ProfileViews error: ${snapshot.error}');
                return Column(
                  children: [
                    _buildViewsHeader(
                        counterViews, isDark, textColor, subtitleColor),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 36, color: subtitleColor),
                              const SizedBox(height: 12),
                              Text(
                                'Viewer details unavailable',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your total view count is shown above.\nDetailed viewer info will be available soon.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final grouped = _groupViewsByViewer(docs);
              final totalViews =
                  docs.isNotEmpty ? docs.length : counterViews;

              return Column(
                children: [
                  _buildViewsHeader(
                      totalViews, isDark, textColor, subtitleColor),
                  Expanded(
                    child: grouped.isEmpty
                        ? _buildEmptyState(isDark, textColor, subtitleColor)
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: grouped.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _buildViewItem(grouped[index],
                                  isDark, textColor, subtitleColor);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildViewsHeader(
      int count, bool isDark, Color textColor, Color subtitleColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.visibility_outlined,
                color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total profile views',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupViewsByViewer(
      List<QueryDocumentSnapshot> docs) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final viewerId = data['viewerId'] as String? ?? doc.id;
      if (grouped.containsKey(viewerId)) {
        grouped[viewerId]!['viewCount'] =
            (grouped[viewerId]!['viewCount'] as int) + 1;
      } else {
        grouped[viewerId] = {
          'viewerId': viewerId,
          'viewerName': data['viewerName'],
          'viewerPhotoUrl': data['viewerPhotoUrl'],
          'viewedAt': data['viewedAt'],
          'viewCount': 1,
        };
      }
    }
    final result = grouped.values.toList();
    result.sort((a, b) {
      final aTime = a['viewedAt'] as Timestamp?;
      final bTime = b['viewedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return result;
  }

  Widget _buildViewItem(Map<String, dynamic> data, bool isDark,
      Color textColor, Color subtitleColor) {
    final viewerId = data['viewerId'] as String?;
    final fallbackName = data['viewerName'] as String? ?? 'Someone';
    final fallbackPhoto = data['viewerPhotoUrl'] as String?;
    final viewCount = data['viewCount'] as int? ?? 1;
    final viewedAt = data['viewedAt'] != null
        ? (data['viewedAt'] as Timestamp).toDate()
        : null;

    // Look up real viewer profile from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: viewerId != null
          ? FirebaseFirestore.instance.collection('users').doc(viewerId).get()
          : null,
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>?;
        final viewerName = userData?['name'] as String? ??
            userData?['displayName'] as String? ??
            fallbackName;
        final viewerPhoto = userData?['profileImageUrl'] as String? ??
            userData?['photoUrl'] as String? ??
            fallbackPhoto;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF0F0F5),
                backgroundImage:
                    viewerPhoto != null && viewerPhoto.isNotEmpty
                        ? CachedNetworkImageProvider(viewerPhoto)
                        : null,
                child: viewerPhoto == null || viewerPhoto.isEmpty
                    ? Text(
                        viewerName.isNotEmpty
                            ? viewerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewerName,
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
                      viewedAt != null
                          ? 'Viewed $viewCount ${viewCount == 1 ? 'time' : 'times'} · ${_formatTime(viewedAt)}'
                          : 'Viewed $viewCount ${viewCount == 1 ? 'time' : 'times'}',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Time ago
              if (viewedAt != null)
                Text(
                  _timeAgo(viewedAt),
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$min $ampm';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Widget _buildEmptyState(
      bool isDark, Color textColor, Color subtitleColor) {
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
            child: Icon(Icons.visibility_off_outlined,
                size: 36,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 16),
          Text(
            'No views yet',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone views your profile,\nit will show up here',
            textAlign: TextAlign.center,
            style: TextStyle(color: subtitleColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
