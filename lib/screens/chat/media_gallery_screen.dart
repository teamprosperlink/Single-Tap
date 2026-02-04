import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

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

        // Filter for images and exclude deleted messages
        final allDocs = snapshot.data!.docs;

        print('  TOTAL MESSAGES: ${allDocs.length}');

        // Check first few messages to see their structure
        for (var i = 0; i < (allDocs.length > 3 ? 3 : allDocs.length); i++) {
          final data = allDocs[i].data() as Map<String, dynamic>;
          print('  MESSAGE $i FIELDS: ${data.keys.toList()}');
          print('   - imageUrl: ${data['imageUrl']}');
          print('   - videoUrl: ${data['videoUrl']}');
          final text = data['text']?.toString() ?? '';
          print(
            '   - text: ${text.length > 30 ? text.substring(0, 30) : text}',
          );
        }

        final photos = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check for imageUrl (group chat) OR mediaUrl with type 'image' (normal chat)
          final imageUrl = data['imageUrl'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            return true;
          }

          // Check for mediaUrl (normal 1-to-1 chat uses this)
          final mediaUrl = data['mediaUrl'];
          final type = data['type']?.toString() ?? '';

          if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
            // Check if it's an image type
            return type == 'image' || _isImageUrl(mediaUrl.toString());
          }

          return false;
        }).toList();

        print('  PHOTOS FOUND: ${photos.length}');

        if (photos.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Photos',
            'Photos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final doc = photos[index];
            final data = doc.data() as Map<String, dynamic>;

            // Try imageUrl first (group chat), then mediaUrl (normal chat)
            final imageUrl = (data['imageUrl'] ?? data['mediaUrl']) as String?;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            if (imageUrl == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: const Text(
                      'Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: timestamp != null
                        ? Text(
                            _formatDateTime(timestamp),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          onPressed: () async {
                            // Show confirmation dialog
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

                            if (confirm == true && _currentUserId != null) {
                              // Mark message as deleted for current user
                              await _firestore
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .collection('messages')
                                  .doc(doc.id)
                                  .set({
                                    'deletedFor': FieldValue.arrayUnion([
                                      _currentUserId,
                                    ]),
                                  }, SetOptions(merge: true));

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
                    onTap: () => PhotoViewerDialog.show(context, imageUrl),
                  ),
                ),
              ),
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

        // Filter for videos and exclude deleted messages
        final allDocs = snapshot.data!.docs;

        final videos = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check for videoUrl (group chat) OR mediaUrl with type 'video' (normal chat)
          final videoUrl = data['videoUrl'];
          if (videoUrl != null && videoUrl.toString().isNotEmpty) {
            return true;
          }

          // Check for mediaUrl (normal 1-to-1 chat uses this)
          final mediaUrl = data['mediaUrl'];
          final type = data['type']?.toString() ?? '';

          if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
            // Check if it's a video type
            return type == 'video' || _isVideoUrl(mediaUrl.toString());
          }

          return false;
        }).toList();

        print('  VIDEOS FOUND: ${videos.length}');

        if (videos.isEmpty) {
          return _buildEmptyState(
            isDarkMode,
            'No Videos',
            'Videos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final doc = videos[index];
            final data = doc.data() as Map<String, dynamic>;

            // Try videoUrl first (group chat), then mediaUrl (normal chat)
            final videoUrl = (data['videoUrl'] ?? data['mediaUrl']) as String?;
            final thumbnail = data['videoThumbnail'] as String?;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            if (videoUrl == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (thumbnail != null)
                              CachedNetworkImage(
                                imageUrl: thumbnail,
                                fit: BoxFit.cover,
                              )
                            else
                              Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.video_library,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            // Play button overlay
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    title: const Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: timestamp != null
                        ? Text(
                            _formatDateTime(timestamp),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 20,
                          ),
                          onPressed: () async {
                            // Show confirmation dialog
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

                            if (confirm == true && _currentUserId != null) {
                              // Mark message as deleted for current user
                              await _firestore
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .collection('messages')
                                  .doc(doc.id)
                                  .set({
                                    'deletedFor': FieldValue.arrayUnion([
                                      _currentUserId,
                                    ]),
                                  }, SetOptions(merge: true));

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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoPlayerScreen(videoUrl: videoUrl),
                        ),
                      );
                    },
                  ),
                ),
              ),
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

        // Filter for links on client side and not deleted by current user
        final allDocs = snapshot.data!.docs;
        final links = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          final message = MessageModel.fromFirestore(doc);
          return message.text != null && _containsUrl(message.text!);
        }).toList();

        final messages = links
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

        // Filter for files and voice messages using fileUrl, voiceUrl, and audioUrl fields and not deleted by current user
        final allDocs = snapshot.data!.docs;

        final files = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

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

        if (files.isEmpty) {
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
          itemCount: files.length,
          itemBuilder: (context, index) {
            final doc = files[index];
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
                            color: Colors.white.withValues(alpha: 0.7),
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

                            if (confirm == true && _currentUserId != null) {
                              // Mark message as deleted for current user
                              await _firestore
                                  .collection('conversations')
                                  .doc(widget.conversationId)
                                  .collection('messages')
                                  .doc(doc.id)
                                  .set({
                                    'deletedFor': FieldValue.arrayUnion([
                                      _currentUserId,
                                    ]),
                                  }, SetOptions(merge: true));

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

                    if (confirm == true && _currentUserId != null) {
                      // Mark message as deleted for current user
                      await _firestore
                          .collection('conversations')
                          .doc(widget.conversationId)
                          .collection('messages')
                          .doc(message.id)
                          .set({
                            'deletedFor': FieldValue.arrayUnion([
                              _currentUserId,
                            ]),
                          }, SetOptions(merge: true));

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

  bool _isVideoUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // Check file extensions (with or without query parameters)
    if (lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm') ||
        lowerUrl.contains('.flv') ||
        lowerUrl.contains('.wmv') ||
        lowerUrl.contains('.m4v')) {
      return true;
    }

    // Check for video-related keywords in URL
    if (lowerUrl.contains('video') || lowerUrl.contains('movie')) {
      return true;
    }

    // Check Firebase Storage video paths
    if (lowerUrl.contains('firebasestorage') &&
        (lowerUrl.contains('%2fvideos%2f') || lowerUrl.contains('/videos/'))) {
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
