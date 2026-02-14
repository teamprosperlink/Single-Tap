import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../home/main_navigation_screen.dart';
import '../chat/video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  List<File> _imageFiles = [];
  List<File> _videoFiles = [];
  List<File> _audioFiles = [];
  List<File> _docFiles = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Multi-select
  bool _isSelectMode = false;
  final Set<String> _selectedPaths = {};

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
    '.heif',
  };
  static const _videoExtensions = {'.mp4', '.mov', '.avi', '.mkv'};
  static const _audioExtensions = {
    '.m4a',
    '.aac',
    '.mp3',
    '.wav',
    '.ogg',
    '.wma',
    '.flac',
  };
  static const _docExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.csv',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          await Permission.photos.request();
        }
      }

      final dirs = await _getDownloadsDirectories();
      final allFiles = <File>[];

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        try {
          final files = dir.listSync(recursive: false).whereType<File>().where((file) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            // Only show files downloaded from chat (plink_ prefix)
            if (!fileName.startsWith('plink_')) return false;
            final ext = fileName.split('.').last.toLowerCase();
            return _imageExtensions.contains('.$ext') ||
                _videoExtensions.contains('.$ext') ||
                _audioExtensions.contains('.$ext') ||
                _docExtensions.contains('.$ext');
          });
          allFiles.addAll(files);
        } catch (e) {
          debugPrint('Error scanning ${dir.path}: $e');
        }
      }

      // Sort by modified date (newest first)
      allFiles.sort((a, b) {
        try {
          final aTime = a.statSync().modified;
          final bTime = b.statSync().modified;
          return bTime.compareTo(aTime);
        } catch (_) {
          return 0;
        }
      });

      final images = <File>[];
      final videos = <File>[];
      final audios = <File>[];
      final docs = <File>[];

      for (final file in allFiles) {
        if (_isDoc(file.path)) {
          docs.add(file);
        } else if (_isAudio(file.path)) {
          audios.add(file);
        } else if (_isVideo(file.path)) {
          videos.add(file);
        } else {
          images.add(file);
        }
      }

      setState(() {
        _imageFiles = images;
        _videoFiles = videos;
        _audioFiles = audios;
        _docFiles = docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      setState(() {
        _imageFiles = [];
        _videoFiles = [];
        _audioFiles = [];
        _docFiles = [];
        _isLoading = false;
      });
    }
  }

  Future<List<Directory>> _getDownloadsDirectories() async {
    final dirs = <Directory>[];

    if (Platform.isAndroid) {
      dirs.add(Directory('/storage/emulated/0/Pictures/Plink'));
    }

    if (Platform.isIOS) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        dirs.add(appDir);
      } catch (e) {
        debugPrint('Error getting app directory: $e');
      }
    }

    return dirs;
  }

  bool _isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _videoExtensions.contains('.$ext');
  }

  bool _isAudio(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _audioExtensions.contains('.$ext');
  }

  bool _isDoc(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _docExtensions.contains('.$ext');
  }

  // ==================== SELECTION MODE ====================

  void _enterSelectMode(File file) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectMode = true;
      _selectedPaths.add(file.path);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelection(File file) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedPaths.contains(file.path)) {
        _selectedPaths.remove(file.path);
        if (_selectedPaths.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedPaths.add(file.path);
      }
    });
  }

  void _selectAllInCurrentTab() {
    final currentFiles = _getCurrentTabFiles();
    setState(() {
      for (final file in currentFiles) {
        _selectedPaths.add(file.path);
      }
    });
  }

  List<File> _getCurrentTabFiles() {
    switch (_tabController.index) {
      case 0:
        return _imageFiles;
      case 1:
        return _videoFiles;
      case 2:
        return _audioFiles;
      case 3:
        return _docFiles;
      default:
        return [];
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedPaths.isEmpty) return;

    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete $count ${count == 1 ? 'file' : 'files'}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '$count ${count == 1 ? 'file' : 'files'} will be permanently deleted from your device.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int deleted = 0;
      int failed = 0;
      for (final path in _selectedPaths.toList()) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            await file.delete();
            deleted++;
          }
        } catch (e) {
          failed++;
          debugPrint('Failed to delete $path: $e');
        }
      }

      _exitSelectMode();
      await _loadFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failed == 0
                  ? '$deleted ${deleted == 1 ? 'file' : 'files'} deleted'
                  : '$deleted deleted, $failed failed',
            ),
            backgroundColor: failed == 0 ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ==================== OPEN FILES ====================

  void _openImage(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullScreenImageViewer(file: file)),
    );
  }

  void _openVideo(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoPlayerScreen(videoUrl: file.path, isLocalFile: true),
      ),
    );
  }

  void _openAudio(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.audio_file_rounded, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Audio file saved on ${_formatFileDate(file)}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _openDoc(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final ext = fileName.split('.').last.toUpperCase();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              ext == 'PDF'
                  ? Icons.picture_as_pdf_rounded
                  : Icons.description_rounded,
              color: ext == 'PDF' ? Colors.redAccent : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          '$ext file saved on ${_formatFileDate(file)}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  String _formatFileDate(File file) {
    try {
      final stat = file.statSync();
      final date = stat.modified;
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'unknown date';
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 52),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(64, 64, 64, 1),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    leading: _isSelectMode
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _exitSelectMode,
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                MainNavigationScreen.scaffoldKey.currentState
                                    ?.openEndDrawer();
                              });
                            },
                          ),
                    title: _isSelectMode
                        ? Text(
                            '${_selectedPaths.length} selected',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Downloads',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    actions: _isSelectMode
                        ? [
                            TextButton(
                              onPressed: _selectAllInCurrentTab,
                              child: Text(
                                'Select All',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ]
                        : null,
                    toolbarHeight: kToolbarHeight - 6,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: !_isSelectMode,
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 2.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Images'),
                      Tab(text: 'Videos'),
                      Tab(text: 'Audio'),
                      Tab(text: 'Docs'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(64, 64, 64, 1),
                  Color.fromRGBO(0, 0, 0, 1),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFileGrid(_imageFiles, 'image'),
                            _buildFileGrid(_videoFiles, 'video'),
                            _buildFileGrid(_audioFiles, 'audio'),
                            _buildFileGrid(_docFiles, 'doc'),
                          ],
                        ),
                      ),
                      // Bottom bar for multi-select delete
                      if (_isSelectMode && _selectedPaths.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1a1a2e,
                            ).withValues(alpha: 0.95),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Text(
                                  '${_selectedPaths.length} ${_selectedPaths.length == 1 ? 'file' : 'files'}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _deleteSelectedFiles,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.withValues(
                                      alpha: 0.8,
                                    ),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileGrid(List<File> files, String type) {
    if (files.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      color: Colors.white,
      backgroundColor: const Color(0xFF1a1a2e),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: (type == 'audio' || type == 'doc') ? 2 : 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: (type == 'audio' || type == 'doc') ? 2.2 : 1.0,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return _buildGridItem(
            file,
            type == 'video',
            type == 'audio',
            type == 'doc',
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    IconData icon;
    String title;
    String subtitle;

    switch (type) {
      case 'image':
        icon = Icons.image_outlined;
        title = 'No images yet';
        subtitle = 'Images you save from\nchats will appear here';
        break;
      case 'video':
        icon = Icons.videocam_outlined;
        title = 'No videos yet';
        subtitle = 'Videos you save from\nchats will appear here';
        break;
      case 'audio':
        icon = Icons.audiotrack_outlined;
        title = 'No audio yet';
        subtitle = 'Audio you save from\nchats will appear here';
        break;
      case 'doc':
        icon = Icons.description_outlined;
        title = 'No documents yet';
        subtitle = 'Documents & PDFs you save\nfrom chats will appear here';
        break;
      default:
        icon = Icons.download_outlined;
        title = 'No downloads yet';
        subtitle = 'Files you save from\nchats will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.4),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(File file, bool isVideo, bool isAudio, bool isDoc) {
    final isSelected = _selectedPaths.contains(file.path);

    return GestureDetector(
      onTap: () {
        if (_isSelectMode) {
          _toggleSelection(file);
        } else {
          HapticFeedback.lightImpact();
          if (isDoc) {
            _openDoc(file);
          } else if (isAudio) {
            _openAudio(file);
          } else if (isVideo) {
            _openVideo(file);
          } else {
            _openImage(file);
          }
        }
      },
      onLongPress: () {
        if (!_isSelectMode) {
          _enterSelectMode(file);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 8 : 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isDoc
                  ? _buildDocTile(file)
                  : isAudio
                  ? _buildAudioTile(file)
                  : isVideo
                  ? _buildVideoTile()
                  : _buildImageTile(file),
              // Selection overlay
              if (_isSelectMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue
                          : Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(File file) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: 300,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white24,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildVideoTile() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: const Icon(
            Icons.videocam_rounded,
            color: Colors.white24,
            size: 32,
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocTile(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final ext = fileName.split('.').last.toUpperCase();
    final isPdf = ext == 'PDF';
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPdf ? Colors.redAccent : Colors.blueAccent).withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
              color: isPdf ? Colors.redAccent : Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$ext  •  ${_formatFileDate(file)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTile(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    return Container(
      color: Colors.white.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.audiotrack_rounded,
              color: Colors.white54,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileDate(file),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_circle_filled_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 28,
          ),
        ],
      ),
    );
  }
}

/// Full screen image viewer for local files
class _FullScreenImageViewer extends StatelessWidget {
  final File file;

  const _FullScreenImageViewer({required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          file.path.split('/').last,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white24,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
