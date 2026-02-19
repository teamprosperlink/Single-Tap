import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../res/config/app_colors.dart';
import 'video_player_screen.dart';
import 'audio_player_dialog.dart';

class GroupMediaGalleryScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupMediaGalleryScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupMediaGalleryScreen> createState() =>
      _GroupMediaGalleryScreenState();
}

class _GroupMediaGalleryScreenState extends State<GroupMediaGalleryScreen>
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

    if (difference.inDays == 0) {
      // Today - show time with "Today"
      return 'Today • ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday • ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return '${DateFormat('EEEE').format(dateTime)} • ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      // Older - show full date
      return '${DateFormat('MMM d, yyyy').format(dateTime)} • ${DateFormat('h:mm a').format(dateTime)}';
    }
  }

  Stream<QuerySnapshot> _getMediaStream(String mediaType) {
    Query query = _firestore
        .collection('conversations')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    switch (mediaType) {
      case 'photos':
        // Return all messages - we'll filter for photos in the UI
        return query.snapshots();
      case 'videos':
        // Return all messages - we'll filter for videos in the UI
        return query.snapshots();
      case 'links':
        // Return all messages - we'll filter for links in the UI
        return query.snapshots();
      case 'files':
        // Return all messages - we'll filter for audio/files in the UI
        return query.snapshots();
      default:
        return query.snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashDark3,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 50),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.splashDark1,
            border: const Border(bottom: BorderSide(color: Colors.white, width: 1)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
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
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Group Media Gallery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPhotosTab(),
              _buildVideosTab(),
              _buildLinksTab(),
              _buildFilesTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMediaStream('photos'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.photo_library_rounded,
            message: 'No Photos',
            subtitle: 'Photos shared in this chat will appear here',
          );
        }

        // Filter for photos and exclude deleted messages
        final allPhotos = snapshot.data!.docs;
        final photos = allPhotos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check for imageUrl OR mediaUrl with type 'image'
          final imageUrl = data['imageUrl'];
          if (imageUrl != null && imageUrl.toString().isNotEmpty) {
            return true;
          }

          // Check for mediaUrl (some messages use this)
          final mediaUrl = data['mediaUrl'];
          final type = data['type']?.toString() ?? '';

          if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
            // Check if it's an image type
            return type == 'image' || _isImageUrl(mediaUrl.toString());
          }

          return false;
        }).toList();

        if (photos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.photo_library_rounded,
            message: 'No Photos',
            subtitle: 'Photos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final doc = photos[index];
            final photo = doc.data() as Map<String, dynamic>;

            // Try imageUrl first, then mediaUrl as fallback
            final imageUrl =
                (photo['imageUrl'] ?? photo['mediaUrl']) as String?;
            final timestamp = (photo['timestamp'] as Timestamp?)?.toDate();

            if (imageUrl == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1),
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
                                  .doc(widget.groupId)
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
                    onTap: () {
                      _showPhotoViewer(imageUrl, timestamp);
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

  Widget _buildVideosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMediaStream('videos'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.video_library_rounded,
            message: 'No Videos',
            subtitle: 'Videos shared in this chat will appear here',
          );
        }

        // Filter for videos and exclude deleted messages
        final allVideos = snapshot.data!.docs;
        final videos = allVideos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check for videoUrl OR mediaUrl with type 'video'
          final videoUrl = data['videoUrl'];
          if (videoUrl != null && videoUrl.toString().isNotEmpty) {
            return true;
          }

          // Check for mediaUrl (some messages use this)
          final mediaUrl = data['mediaUrl'];
          final type = data['type']?.toString() ?? '';

          if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
            // Check if it's a video type
            return type == 'video' || _isVideoUrl(mediaUrl.toString());
          }

          return false;
        }).toList();

        if (videos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.video_library_rounded,
            message: 'No Videos',
            subtitle: 'Videos shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final doc = videos[index];
            final video = doc.data() as Map<String, dynamic>;

            // Try videoUrl first, then mediaUrl as fallback
            final videoUrl =
                (video['videoUrl'] ?? video['mediaUrl']) as String?;
            final thumbnail = video['videoThumbnail'] as String?;
            final timestamp = (video['timestamp'] as Timestamp?)?.toDate();

            if (videoUrl == null) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1),
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
                                  .doc(widget.groupId)
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

  Widget _buildLinksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMediaStream('links'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_rounded,
            message: 'No Links',
            subtitle: 'Links shared in this chat will appear here',
          );
        }

        // URL detection regex pattern
        final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

        // Filter messages containing URLs and not deleted by current user
        final allMessages = snapshot.data!.docs;
        final links = allMessages.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check if message has a URL in text
          final text = data['text'] as String?;
          if (text != null && urlPattern.hasMatch(text)) {
            return true;
          }

          // Also check for explicit linkUrl field
          final linkUrl = data['linkUrl'] as String?;
          return linkUrl != null && linkUrl.isNotEmpty;
        }).toList();

        if (links.isEmpty) {
          return _buildEmptyState(
            icon: Icons.link_rounded,
            message: 'No Links',
            subtitle: 'Links shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: links.length,
          itemBuilder: (context, index) {
            final link = links[index].data() as Map<String, dynamic>;
            final text = link['text'] as String?;
            final linkUrl = link['linkUrl'] as String?;
            final timestamp = (link['timestamp'] as Timestamp?)?.toDate();

            // Extract URL from text or use linkUrl field
            String? extractedUrl = linkUrl;
            if (extractedUrl == null && text != null) {
              final match = urlPattern.firstMatch(text);
              extractedUrl = match?.group(0);
            }

            if (extractedUrl == null) return const SizedBox.shrink();

            // Make URL non-nullable for use in widget
            final String url = extractedUrl;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      url,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                    trailing: IconButton(
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
                              .doc(widget.groupId)
                              .collection('messages')
                              .doc(links[index].id)
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
                    onTap: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open link'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
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

  Widget _buildFilesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getMediaStream('files'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.insert_drive_file_rounded,
            message: 'No Files',
            subtitle: 'Files and audio shared in this chat will appear here',
          );
        }

        // Filter for audio files, voice messages, and documents
        final allMessages = snapshot.data!.docs;
        final files = allMessages.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if deleted by current user
          final deletedFor = data['deletedFor'] as List<dynamic>?;
          if (deletedFor != null && _currentUserId != null) {
            if (deletedFor.contains(_currentUserId)) return false;
          }

          // Check if it has audio, voice, or file URL
          final hasAudioUrl =
              data['audioUrl'] != null &&
              (data['audioUrl'] as String).isNotEmpty;
          final hasVoiceUrl =
              data['voiceUrl'] != null &&
              (data['voiceUrl'] as String).isNotEmpty;
          final hasFileUrl =
              data['fileUrl'] != null && (data['fileUrl'] as String).isNotEmpty;

          return hasAudioUrl || hasVoiceUrl || hasFileUrl;
        }).toList();

        if (files.isEmpty) {
          return _buildEmptyState(
            icon: Icons.insert_drive_file_rounded,
            message: 'No Files',
            subtitle: 'Files and audio shared in this chat will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index].data() as Map<String, dynamic>;
            final audioUrl = file['audioUrl'] as String?;
            final voiceUrl = file['voiceUrl'] as String?;
            final fileUrl = file['fileUrl'] as String?;
            final fileName = file['fileName'] as String?;
            final timestamp = (file['timestamp'] as Timestamp?)?.toDate();

            // Determine file type and properties
            final bool isAudio =
                (audioUrl != null && audioUrl.isNotEmpty) ||
                (voiceUrl != null && voiceUrl.isNotEmpty);
            final String url = audioUrl ?? voiceUrl ?? fileUrl ?? '';
            final String displayName = isAudio
                ? (fileName ?? 'Voice Message')
                : (fileName ?? 'Document');
            final IconData icon = isAudio ? Icons.mic : Icons.insert_drive_file;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    trailing: IconButton(
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
                            title: Text(
                              isAudio ? 'Delete Audio' : 'Delete File',
                            ),
                            content: Text(
                              isAudio
                                  ? 'Delete this audio?'
                                  : 'Delete this file?',
                            ),
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
                              .doc(widget.groupId)
                              .collection('messages')
                              .doc(files[index].id)
                              .set({
                                'deletedFor': FieldValue.arrayUnion([
                                  _currentUserId,
                                ]),
                              }, SetOptions(merge: true));

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAudio ? 'Audio deleted' : 'File deleted',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    onTap: () {
                      if (isAudio) {
                        // Play audio
                        AudioPlayerDialog.show(
                          context,
                          url,
                          title: displayName,
                        );
                      } else {
                        // Download file
                      }
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

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Icon(
              icon,
              size: 60,
              color: Colors.white30,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoViewer(String imageUrl, DateTime? timestamp) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
            // Date/time info
            if (timestamp != null)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDateTime(timestamp),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}
