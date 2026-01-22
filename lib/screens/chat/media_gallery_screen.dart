import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../models/message_model.dart';
import 'video_player_screen.dart';
import 'audio_player_dialog.dart';
import 'photo_viewer_dialog.dart';
import 'link_preview_dialog.dart';

class MediaGalleryScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;

  const MediaGalleryScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 7) {
      // Show day and time for recent items (within a week)
      return '${DateFormat('EEE, MMM d').format(dateTime)} • ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      // Show full date and time for older items
      return '${DateFormat('MMM d, yyyy').format(dateTime)} • ${DateFormat('h:mm a').format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: isDarkMode ? Colors.white : AppColors.iosBlue,
                indicatorWeight: 3,
                labelColor: isDarkMode ? Colors.white : AppColors.iosBlue,
                unselectedLabelColor: isDarkMode
                    ? Colors.white60
                    : Colors.black54,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Photos'),
                  Tab(text: 'Videos'),
                  Tab(text: 'Links'),
                  Tab(text: 'Files'),
                ],
              ),
            ],
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDarkMode ? Colors.white : AppColors.iosBlue,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Media Gallery',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image - Same as chat screen
          Positioned.fill(
            child: Image.asset(
              AppAssets.homeBackgroundImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Dark overlay - Heavier for better contrast
          Positioned.fill(
            child: Container(color: AppColors.darkOverlay(alpha: 0.5)),
          ),
          // Content
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPhotosTab(isDarkMode),
                _buildVideosTab(isDarkMode),
                _buildLinksTab(isDarkMode),
                _buildFilesTab(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDarkMode);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Photos',
            'Photos shared in this chat will appear here',
          );
        }

        // Filter for images using imageUrl field
        final allDocs = snapshot.data!.docs;

        final imageDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['imageUrl'] != null &&
              (data['imageUrl'] as String).isNotEmpty;
        }).toList();

        // Remove duplicates using smart matching (sender + timestamp proximity)
        final List<QueryDocumentSnapshot> deduplicatedImageDocs = [];
        final Set<int> skipIndices = {};

        for (int i = 0; i < imageDocs.length; i++) {
          if (skipIndices.contains(i)) continue;

          final doc = imageDocs[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] as String?;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final imageUrl = data['imageUrl'] as String?;

          // Check if this is a duplicate of any later message
          bool isDuplicate = false;
          for (int j = i + 1; j < imageDocs.length; j++) {
            if (skipIndices.contains(j)) continue;

            final otherDoc = imageDocs[j];
            final otherData = otherDoc.data() as Map<String, dynamic>;
            final otherSenderId = otherData['senderId'] as String?;
            final otherTimestamp = (otherData['timestamp'] as Timestamp?)
                ?.toDate();
            final otherImageUrl = otherData['imageUrl'] as String?;

            // Same sender and (same URL OR close timestamps)
            if (senderId == otherSenderId) {
              bool isSameUrl = imageUrl == otherImageUrl;
              bool isCloseTimestamp = false;

              // Check if timestamps are very close (within 2 minutes)
              if (timestamp != null && otherTimestamp != null) {
                final difference = timestamp.difference(otherTimestamp).abs();
                if (difference.inMinutes < 2) {
                  isCloseTimestamp = true;
                }
              }

              // If same sender and (same URL OR close timestamps), consider as duplicate
              if (isSameUrl || isCloseTimestamp) {
                // Keep the newer message, skip the older one
                if (timestamp != null && otherTimestamp != null) {
                  if (timestamp.isAfter(otherTimestamp)) {
                    skipIndices.add(j); // Skip the older message
                  } else {
                    isDuplicate = true; // This message is older, skip it
                    skipIndices.add(i);
                    break;
                  }
                }
              }
            }
          }

          if (!isDuplicate) {
            deduplicatedImageDocs.add(doc);
          }
        }

        // Debug logging
        print('📊 Photos Tab: Total messages: ${allDocs.length}');
        print('📸 Photos Tab: Messages with imageUrl: ${imageDocs.length}');
        print('✨ After deduplication: ${deduplicatedImageDocs.length}');
        if (deduplicatedImageDocs.isNotEmpty) {
          final firstDoc =
              deduplicatedImageDocs.first.data() as Map<String, dynamic>;
          print(
            '🔍 Sample imageUrl: ${(firstDoc['imageUrl'] as String).substring(0, 50)}...',
          );
        }

        if (deduplicatedImageDocs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Photos',
            'Photos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          itemCount: deduplicatedImageDocs.length,
          itemBuilder: (context, index) {
            final doc = deduplicatedImageDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] as String;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1A2B3D)
                        : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => PhotoViewerDialog.show(context, imageUrl),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Image thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: isDarkMode
                                        ? Colors.grey[800]
                                        : Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: isDarkMode
                                            ? Colors.grey[800]
                                            : Colors.grey[300],
                                        child: Icon(
                                          Icons.error_outline,
                                          color: isDarkMode
                                              ? Colors.white30
                                              : Colors.black26,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Photo label
                            Expanded(
                              child: Text(
                                'Photo',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.withValues(alpha: 0.7),
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Photo'),
                                    content: const Text('Delete this photo?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _firestore
                                      .collection('conversations')
                                      .doc(widget.conversationId)
                                      .collection('messages')
                                      .doc(doc.id)
                                      .delete();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Photo deleted'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Timestamp outside card
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 12),
                    child: Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white60 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVideosTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDarkMode);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Videos',
            'Videos shared in this chat will appear here',
          );
        }

        // Filter for videos using videoUrl field
        final allDocs = snapshot.data!.docs;

        final videoDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['videoUrl'] != null &&
              (data['videoUrl'] as String).isNotEmpty;
        }).toList();

        // Remove duplicates using smart matching (sender + timestamp proximity)
        final List<QueryDocumentSnapshot> deduplicatedVideoDocs = [];
        final Set<int> skipIndices = {};

        for (int i = 0; i < videoDocs.length; i++) {
          if (skipIndices.contains(i)) continue;

          final doc = videoDocs[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] as String?;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final videoUrl = data['videoUrl'] as String?;

          // Check if this is a duplicate of any later message
          bool isDuplicate = false;
          for (int j = i + 1; j < videoDocs.length; j++) {
            if (skipIndices.contains(j)) continue;

            final otherDoc = videoDocs[j];
            final otherData = otherDoc.data() as Map<String, dynamic>;
            final otherSenderId = otherData['senderId'] as String?;
            final otherTimestamp = (otherData['timestamp'] as Timestamp?)
                ?.toDate();
            final otherVideoUrl = otherData['videoUrl'] as String?;

            // Same sender and (same URL OR close timestamps)
            if (senderId == otherSenderId) {
              bool isSameUrl = videoUrl == otherVideoUrl;
              bool isCloseTimestamp = false;

              // Check if timestamps are very close (within 2 minutes)
              if (timestamp != null && otherTimestamp != null) {
                final difference = timestamp.difference(otherTimestamp).abs();
                if (difference.inMinutes < 2) {
                  isCloseTimestamp = true;
                }
              }

              // If same sender and (same URL OR close timestamps), consider as duplicate
              if (isSameUrl || isCloseTimestamp) {
                // Keep the newer message, skip the older one
                if (timestamp != null && otherTimestamp != null) {
                  if (timestamp.isAfter(otherTimestamp)) {
                    skipIndices.add(j); // Skip the older message
                  } else {
                    isDuplicate = true; // This message is older, skip it
                    skipIndices.add(i);
                    break;
                  }
                }
              }
            }
          }

          if (!isDuplicate) {
            deduplicatedVideoDocs.add(doc);
          }
        }

        // Debug logging
        print('📊 Videos Tab: Total messages: ${allDocs.length}');
        print('🎥 Videos Tab: Messages with videoUrl: ${videoDocs.length}');
        print('✨ After deduplication: ${deduplicatedVideoDocs.length}');
        if (deduplicatedVideoDocs.isNotEmpty) {
          final firstDoc =
              deduplicatedVideoDocs.first.data() as Map<String, dynamic>;
          print(
            '🔍 Sample videoUrl: ${(firstDoc['videoUrl'] as String).substring(0, 50)}...',
          );
        }

        if (deduplicatedVideoDocs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Videos',
            'Videos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          itemCount: deduplicatedVideoDocs.length,
          itemBuilder: (context, index) {
            final doc = deduplicatedVideoDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final videoUrl = data['videoUrl'] as String;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1A2B3D)
                        : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VideoPlayerScreen(videoUrl: videoUrl),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Video icon
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_circle_outline,
                                color: Colors.deepPurple,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Video label
                            Expanded(
                              child: Text(
                                'Video',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.withValues(alpha: 0.7),
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Video'),
                                    content: const Text('Delete this video?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _firestore
                                      .collection('conversations')
                                      .doc(widget.conversationId)
                                      .collection('messages')
                                      .doc(doc.id)
                                      .delete();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Video deleted'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Timestamp outside card
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 12),
                    child: Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white60 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLinksTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDarkMode);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Links',
            'Links shared in this chat will appear here',
          );
        }

        // Filter for links on client side
        final allDocs = snapshot.data!.docs;
        final linkDocs = allDocs.where((doc) {
          final message = MessageModel.fromFirestore(doc);
          return message.text != null && _containsUrl(message.text!);
        }).toList();

        // Remove duplicates using smart matching (sender + timestamp proximity or same URL)
        final List<QueryDocumentSnapshot> deduplicatedLinkDocs = [];
        final Set<int> skipIndices = {};

        for (int i = 0; i < linkDocs.length; i++) {
          if (skipIndices.contains(i)) continue;

          final doc = linkDocs[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] as String?;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final text = data['text'] as String?;
          final urls = text != null ? _extractUrls(text) : <String>[];

          // Check if this is a duplicate of any later message
          bool isDuplicate = false;
          for (int j = i + 1; j < linkDocs.length; j++) {
            if (skipIndices.contains(j)) continue;

            final otherDoc = linkDocs[j];
            final otherData = otherDoc.data() as Map<String, dynamic>;
            final otherSenderId = otherData['senderId'] as String?;
            final otherTimestamp = (otherData['timestamp'] as Timestamp?)
                ?.toDate();
            final otherText = otherData['text'] as String?;
            final otherUrls = otherText != null
                ? _extractUrls(otherText)
                : <String>[];

            // Same sender and (same URLs OR close timestamps)
            if (senderId == otherSenderId) {
              bool hasSameUrl = false;
              bool isCloseTimestamp = false;

              // Check if they share any URL
              for (final url in urls) {
                if (otherUrls.contains(url)) {
                  hasSameUrl = true;
                  break;
                }
              }

              // Check if timestamps are very close (within 2 minutes)
              if (timestamp != null && otherTimestamp != null) {
                final difference = timestamp.difference(otherTimestamp).abs();
                if (difference.inMinutes < 2) {
                  isCloseTimestamp = true;
                }
              }

              // If same sender and (same URL OR close timestamps), consider as duplicate
              if (hasSameUrl || isCloseTimestamp) {
                // Keep the newer message, skip the older one
                if (timestamp != null && otherTimestamp != null) {
                  if (timestamp.isAfter(otherTimestamp)) {
                    skipIndices.add(j); // Skip the older message
                  } else {
                    isDuplicate = true; // This message is older, skip it
                    skipIndices.add(i);
                    break;
                  }
                }
              }
            }
          }

          if (!isDuplicate) {
            deduplicatedLinkDocs.add(doc);
          }
        }

        final messages = deduplicatedLinkDocs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();

        if (messages.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Links',
            'Links shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildLinkItem(message, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildFilesTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isDarkMode);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Files',
            'Documents and files shared in this chat will appear here',
          );
        }

        // Filter for files and voice messages using fileUrl, voiceUrl, and audioUrl fields
        final allDocs = snapshot.data!.docs;

        final fileDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final hasFileUrl =
              data['fileUrl'] != null && (data['fileUrl'] as String).isNotEmpty;
          final hasVoiceUrl =
              data['voiceUrl'] != null &&
              (data['voiceUrl'] as String).isNotEmpty;
          final hasAudioUrl =
              data['audioUrl'] != null &&
              (data['audioUrl'] as String).isNotEmpty;
          return hasFileUrl || hasVoiceUrl || hasAudioUrl;
        }).toList();

        // Remove duplicates using smart matching (sender + duration or timestamp proximity)
        final List<QueryDocumentSnapshot> deduplicatedFileDocs = [];
        final Set<int> skipIndices = {};

        for (int i = 0; i < fileDocs.length; i++) {
          if (skipIndices.contains(i)) continue;

          final doc = fileDocs[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] as String?;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final audioDuration = data['audioDuration'] as int?;
          final isAudio = data['voiceUrl'] != null || data['audioUrl'] != null;

          // Check if this is a duplicate of any later message
          bool isDuplicate = false;
          for (int j = i + 1; j < fileDocs.length; j++) {
            if (skipIndices.contains(j)) continue;

            final otherDoc = fileDocs[j];
            final otherData = otherDoc.data() as Map<String, dynamic>;
            final otherSenderId = otherData['senderId'] as String?;
            final otherTimestamp = (otherData['timestamp'] as Timestamp?)
                ?.toDate();
            final otherAudioDuration = otherData['audioDuration'] as int?;
            final otherIsAudio =
                otherData['voiceUrl'] != null || otherData['audioUrl'] != null;

            // Only compare audio messages with audio messages
            if (isAudio && otherIsAudio && senderId == otherSenderId) {
              bool isSameDuration = false;
              bool isCloseTimestamp = false;

              // Check if same duration
              if (audioDuration != null &&
                  otherAudioDuration != null &&
                  audioDuration == otherAudioDuration) {
                isSameDuration = true;
              }

              // Check if timestamps are very close (within 2 minutes)
              if (timestamp != null && otherTimestamp != null) {
                final difference = timestamp.difference(otherTimestamp).abs();
                if (difference.inMinutes < 2) {
                  isCloseTimestamp = true;
                }
              }

              // If same sender and (same duration OR close timestamps), consider as duplicate
              if (isSameDuration || isCloseTimestamp) {
                // Keep the newer message, skip the older one
                if (timestamp != null && otherTimestamp != null) {
                  if (timestamp.isAfter(otherTimestamp)) {
                    skipIndices.add(j); // Skip the older message
                  } else {
                    isDuplicate = true; // This message is older, skip it
                    skipIndices.add(i);
                    break;
                  }
                }
              }
            }
          }

          if (!isDuplicate) {
            deduplicatedFileDocs.add(doc);
          }
        }

        // Debug logging
        print('📊 Files Tab: Total messages: ${allDocs.length}');
        print(
          '📁 Files Tab: Messages with fileUrl/voiceUrl/audioUrl: ${fileDocs.length}',
        );
        print('✨ After deduplication: ${deduplicatedFileDocs.length}');

        // Show details of each file/audio
        for (int i = 0; i < deduplicatedFileDocs.length; i++) {
          final data = deduplicatedFileDocs[i].data() as Map<String, dynamic>;
          final hasFileUrl = data['fileUrl'] != null;
          final hasVoiceUrl = data['voiceUrl'] != null;
          final hasAudioUrl = data['audioUrl'] != null;
          final fileName = data['fileName'] ?? 'Unknown';
          final timestamp = data['timestamp'];

          print('📄 File ${i + 1}:');
          print('   - Name: $fileName');
          print('   - Has fileUrl: $hasFileUrl');
          print('   - Has voiceUrl: $hasVoiceUrl');
          print('   - Has audioUrl: $hasAudioUrl');
          print('   - Timestamp: $timestamp');
          print('   - Document ID: ${deduplicatedFileDocs[i].id}');
        }

        if (deduplicatedFileDocs.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Files',
            'Documents and files shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          itemCount: deduplicatedFileDocs.length,
          itemBuilder: (context, index) {
            final doc = deduplicatedFileDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fileUrl =
                (data['fileUrl'] ?? data['voiceUrl'] ?? data['audioUrl'])
                    as String;
            final isVoice =
                data['voiceUrl'] != null || data['audioUrl'] != null;
            final fileName =
                data['fileName'] as String? ??
                (isVoice ? 'Voice Message' : 'File');
            final timestamp = data['timestamp'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1A2B3D)
                    : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (isVoice) {
                      AudioPlayerDialog.show(context, fileUrl, title: fileName);
                    } else {
                      _openUrl(fileUrl);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (isVoice ? Colors.green : AppColors.iosBlue)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isVoice ? Icons.mic : Icons.insert_drive_file,
                            color: isVoice ? Colors.green : AppColors.iosBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(timestamp.toDate()),
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white60
                                        : Colors.black45,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          onPressed: () async {
                            // Show confirmation dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Media'),
                                content: Text(
                                  'Delete this ${isVoice ? 'voice message' : 'file'}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              // Delete the message from Firestore
                              await _firestore
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .collection('messages')
                                  .doc(doc.id)
                                  .delete();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${isVoice ? 'Voice message' : 'File'} deleted',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMediaItem(MessageModel message, bool isDarkMode) {
    final isImage = message.mediaUrl != null && _isImageUrl(message.mediaUrl!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isImage) {
              _showFullScreenImage(message.mediaUrl!);
            } else {
              _openUrl(message.mediaUrl!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail or icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF0A1828)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: message.mediaUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error_outline),
                          ),
                        )
                      : Icon(
                          _getFileIcon(message.mediaUrl!),
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isImage ? 'Photo' : _getFileName(message.mediaUrl!),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(message.timestamp),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Forward arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGridItem(MessageModel message, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(message.mediaUrl!),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A2B3D) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error_outline),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkItem(MessageModel message, bool isDarkMode) {
    final urls = _extractUrls(message.text!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (urls.isNotEmpty) {
              LinkPreviewDialog.show(
                context,
                urls.first,
                messageText: message.text,
                timestamp: message.timestamp,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.iosBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: AppColors.iosBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urls.isNotEmpty ? urls.first : message.text!,
                        style: TextStyle(
                          color: AppColors.iosBlue,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(message.timestamp),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Link'),
                        content: const Text('Delete this link?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      // Delete the message from Firestore
                      await _firestore
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .collection('messages')
                          .doc(message.id)
                          .delete();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(MessageModel message, bool isDarkMode) {
    final fileName = _getFileName(message.mediaUrl!);
    final fileExtension = _getFileExtension(message.mediaUrl!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2B3D) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openUrl(message.mediaUrl!),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _getFileColor(fileExtension).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(message.mediaUrl!),
                        color: _getFileColor(fileExtension),
                        size: 24,
                      ),
                      if (fileExtension.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          fileExtension.toUpperCase(),
                          style: TextStyle(
                            color: _getFileColor(fileExtension),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(message.timestamp),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white60 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1A2B3D)
                  : const Color(0xFFF0F2F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 60,
              color: isDarkMode ? Colors.white30 : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          isDarkMode ? Colors.white70 : AppColors.iosBlue,
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error_outline, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // Check file extensions (with or without query parameters)
    if (lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.gif') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.bmp') ||
        lowerUrl.contains('.heic') ||
        lowerUrl.contains('.heif')) {
      return true;
    }

    // Check for image-related keywords in URL
    if (lowerUrl.contains('image') ||
        lowerUrl.contains('photo') ||
        lowerUrl.contains('picture') ||
        lowerUrl.contains('img')) {
      return true;
    }

    // Check Firebase Storage image paths
    if (lowerUrl.contains('firebasestorage') &&
        (lowerUrl.contains('%2fimages%2f') ||
            lowerUrl.contains('/images/') ||
            lowerUrl.contains('%2fphotos%2f') ||
            lowerUrl.contains('/photos/'))) {
      return true;
    }

    return false;
  }

  bool _containsUrl(String text) {
    final urlPattern = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    return urlPattern.hasMatch(text);
  }

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    final matches = urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        var fileName = pathSegments.last;
        // Remove query parameters
        fileName = fileName.split('?').first;
        return fileName;
      }
    } catch (e) {
      // If parsing fails, return a default name
    }
    return 'File';
  }

  String _getFileExtension(String url) {
    final fileName = _getFileName(url);
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last;
    }
    return '';
  }

  IconData _getFileIcon(String url) {
    final extension = _getFileExtension(url).toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Colors.pink;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }
}
