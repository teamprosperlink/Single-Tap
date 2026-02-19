import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/main_navigation_screen.dart';

/// SingleTap-style Projects / Library screen
class LibraryScreen extends StatefulWidget {
  final Function(String chatId)? onLoadChat;
  final Function(String projectId)? onNewChatInProject;

  const LibraryScreen({super.key, this.onLoadChat, this.onNewChatInProject});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('projects')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .get();

      final projects = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        projects.add({'id': doc.id, ...data});
      }

      // Sort: newest first
      projects.sort((a, b) {
        final aTime = a['updatedAt'] as Timestamp?;
        final bTime = b['updatedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CreateProjectDialog(),
    );

    if (result == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('projects').add({
        'userId': user.uid,
        'name': result['name'],
        'description': result['description'] ?? '',
        'color': result['color'] ?? 0xFF6C63FF,
        'icon': result['icon'] ?? 'folder',
        'customInstructions': '',
        'chatIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadProjects();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${result['name']}" created'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating project: $e');
    }
  }

  Future<void> _deleteProject(String projectId, String projectName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Project?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will delete "$projectName" and remove all chats from this project. The chats themselves won\'t be deleted.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Remove projectId from all associated chats
      final project = _projects.firstWhere(
        (p) => p['id'] == projectId,
        orElse: () => {},
      );
      final chatIds = List<String>.from(project['chatIds'] ?? []);
      for (final chatId in chatIds) {
        await _firestore.collection('chat_history').doc(chatId).update({
          'projectId': FieldValue.delete(),
        });
      }

      await _firestore.collection('projects').doc(projectId).delete();
      await _loadProjects();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$projectName" deleted'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
    }
  }

  Future<void> _renameProject(String projectId, String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rename Project',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Project name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await _firestore.collection('projects').doc(projectId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadProjects();
    } catch (e) {
      debugPrint('Error renaming project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(64, 64, 64, 1),
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 1),
                ),
              ),
              child: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      MainNavigationScreen.scaffoldKey.currentState
                          ?.openEndDrawer();
                    });
                  },
                ),
                title: const Text(
                  'Library',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
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
                : _projects.isEmpty
                ? _buildEmptyState()
                : _buildProjectsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        backgroundColor: const Color(0xFF016CFF),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Project',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Projects Yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create projects to organize your chats, add custom instructions, and keep related conversations together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _createProject,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C63FF)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Create Project',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _buildProjectsList() {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: Colors.white,
      backgroundColor: const Color(0xFF2D2D3D),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _projects.length,
        itemBuilder: (context, index) => _buildProjectCard(_projects[index]),
      ),
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final projectId = project['id'] as String;
    final name = project['name'] ?? 'Untitled';
    final description = project['description'] ?? '';
    final colorValue = project['color'] ?? 0xFF6C63FF;
    final color = Color(colorValue);
    final chatIds = List<String>.from(project['chatIds'] ?? []);
    final chatCount = chatIds.length;
    final updatedAt = project['updatedAt'] as Timestamp?;

    String timeAgo = '';
    if (updatedAt != null) {
      final diff = DateTime.now().difference(updatedAt.toDate());
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inHours < 1) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        timeAgo = '${diff.inDays}d ago';
      } else {
        timeAgo = '${(diff.inDays / 7).floor()}w ago';
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openProjectDetail(project);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Project icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getProjectIcon(project['icon']),
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                // Project name & info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$chatCount chat${chatCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                          if (timeAgo.isNotEmpty) ...[
                            Text(
                              '  \u00B7  $timeAgo',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu button
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  color: const Color(0xFF2D2D3D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _renameProject(projectId, name);
                        break;
                      case 'delete':
                        _deleteProject(projectId, name);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    _buildMenuItem(Icons.edit_outlined, 'Rename', 'rename'),
                    const PopupMenuDivider(),
                    _buildMenuItem(
                      Icons.delete_outline,
                      'Delete',
                      'delete',
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    IconData icon,
    String label,
    String value, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProjectIcon(String? iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'school':
        return Icons.school_outlined;
      case 'favorite':
        return Icons.favorite_outline_rounded;
      case 'star':
        return Icons.star_outline_rounded;
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'music':
        return Icons.music_note_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'book':
        return Icons.menu_book_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  void _openProjectDetail(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProjectDetailScreen(
          project: project,
          onLoadChat: widget.onLoadChat,
          onNewChatInProject: widget.onNewChatInProject,
          onRefresh: _loadProjects,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Create Project Dialog
// ──────────────────────────────────────────────────────────
class _CreateProjectDialog extends StatefulWidget {
  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  final int _selectedColor = 0xFF016CFF;
  String _selectedIcon = 'folder';

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'folder', 'icon': Icons.folder_outlined},
    {'name': 'work', 'icon': Icons.work_outline_rounded},
    {'name': 'code', 'icon': Icons.code_rounded},
    {'name': 'school', 'icon': Icons.school_outlined},
    {'name': 'star', 'icon': Icons.star_outline_rounded},
    {'name': 'lightbulb', 'icon': Icons.lightbulb_outline_rounded},
    {'name': 'book', 'icon': Icons.menu_book_outlined},
    {'name': 'shopping', 'icon': Icons.shopping_bag_outlined},
    {'name': 'food', 'icon': Icons.restaurant_outlined},
    {'name': 'travel', 'icon': Icons.flight_outlined},
    {'name': 'music', 'icon': Icons.music_note_outlined},
    {'name': 'fitness', 'icon': Icons.fitness_center_outlined},
    {'name': 'favorite', 'icon': Icons.favorite_outline_rounded},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'New Project',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Project name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF016CFF),
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.edit,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Icon picker
              Text(
                'Icon',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((opt) {
                  final isSelected = opt['name'] == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = opt['name']),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColor).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: Color(_selectedColor),
                                width: 1.5,
                              )
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                      ),
                      child: Icon(
                        opt['icon'] as IconData,
                        color: isSelected
                            ? Color(_selectedColor)
                            : Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Please enter a project name'),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'name': name,
              'color': _selectedColor,
              'icon': _selectedIcon,
            });
          },
          child: const Text(
            'Create',
            style: TextStyle(
              color: Color(0xFF016CFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Project Detail Screen
// ──────────────────────────────────────────────────────────
class _ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final Function(String chatId)? onLoadChat;
  final Function(String projectId)? onNewChatInProject;
  final VoidCallback? onRefresh;

  const _ProjectDetailScreen({
    required this.project,
    this.onLoadChat,
    this.onNewChatInProject,
    this.onRefresh,
  });

  @override
  State<_ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<_ProjectDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _projectChats = [];
  bool _isLoading = true;
  late Map<String, dynamic> _project;

  @override
  void initState() {
    super.initState();
    _project = Map<String, dynamic>.from(widget.project);
    _loadProjectChats();
  }

  Future<void> _loadProjectChats() async {
    try {
      final chatIds = List<String>.from(_project['chatIds'] ?? []);
      final chats = <Map<String, dynamic>>[];

      for (final chatId in chatIds) {
        final doc = await _firestore
            .collection('chat_history')
            .doc(chatId)
            .get();
        if (doc.exists) {
          chats.add({'id': doc.id, ...doc.data()!});
        }
      }

      // Sort by updatedAt
      chats.sort((a, b) {
        final aTime = a['updatedAt'] as Timestamp?;
        final bTime = b['updatedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _projectChats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading project chats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addExistingChats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Load all user chats that are NOT in any project
      final allChats = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .get();

      final existingChatIds = Set<String>.from(_project['chatIds'] ?? []);

      final availableChats = allChats.docs
          .where((doc) => !existingChatIds.contains(doc.id))
          .map(
            (doc) => {
              'id': doc.id,
              'title': doc.data()['title'] ?? 'Chat',
              'createdAt': doc.data()['createdAt'],
              'selected': false,
            },
          )
          .toList();

      if (availableChats.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No available chats to add'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      // Sort by newest first
      availableChats.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      final selectedIds = await showModalBottomSheet<List<String>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _AddChatsBottomSheet(chats: availableChats),
      );

      if (selectedIds == null || selectedIds.isEmpty) return;

      // Add selected chats to project
      final updatedChatIds = [...existingChatIds, ...selectedIds];
      await _firestore.collection('projects').doc(_project['id']).update({
        'chatIds': updatedChatIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also tag each chat with projectId
      for (final chatId in selectedIds) {
        await _firestore.collection('chat_history').doc(chatId).update({
          'projectId': _project['id'],
        });
      }

      _project['chatIds'] = updatedChatIds;
      await _loadProjectChats();
      widget.onRefresh?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedIds.length} chat${selectedIds.length > 1 ? 's' : ''} added',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding chats: $e');
    }
  }

  Future<void> _removeChatFromProject(String chatId) async {
    try {
      final chatIds = List<String>.from(_project['chatIds'] ?? []);
      chatIds.remove(chatId);

      await _firestore.collection('projects').doc(_project['id']).update({
        'chatIds': chatIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('chat_history').doc(chatId).update({
        'projectId': FieldValue.delete(),
      });

      _project['chatIds'] = chatIds;
      await _loadProjectChats();
      widget.onRefresh?.call();
    } catch (e) {
      debugPrint('Error removing chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _project['name'] ?? 'Untitled';
    final colorValue = _project['color'] ?? 0xFF6C63FF;
    final color = Color(colorValue);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(64, 64, 64, 1),
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 1),
                ),
              ),
              child: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
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
            child: Column(
              children: [
                // Chats list
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _projectChats.isEmpty
                      ? _buildEmptyChatsState(color)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _projectChats.length,
                          itemBuilder: (context, index) =>
                              _buildChatTile(_projectChats[index], color),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Floating New Chat button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewChat(),
        backgroundColor: const Color(0xFF016CFF),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _startNewChat() {
    HapticFeedback.mediumImpact();
    final projectId = _project['id'] as String;
    Navigator.pop(context); // Close detail screen
    Navigator.pop(context); // Close library screen
    widget.onNewChatInProject?.call(projectId);
  }

  Widget _buildEmptyChatsState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Colors.white.withValues(alpha: 0.3),
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            'No chats in this project',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat or add existing ones',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          // Start New Chat button
          GestureDetector(
            onTap: _startNewChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Start New Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Add existing chats button
          GestureDetector(
            onTap: _addExistingChats,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Add Existing Chats',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  Widget _buildChatTile(Map<String, dynamic> chat, Color color) {
    final chatId = chat['id'] as String;
    final title = chat['title'] ?? 'Chat';
    final updatedAt = chat['updatedAt'] as Timestamp?;

    String timeStr = '';
    if (updatedAt != null) {
      final diff = DateTime.now().difference(updatedAt.toDate());
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${diff.inDays}d ago';
      }
    }

    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.remove_circle_outline,
          color: Colors.red,
          size: 22,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Remove from project?',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Text(
              'This will remove "$title" from the project. The chat itself won\'t be deleted.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _removeChatFromProject(chatId),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context); // Close detail screen
          Navigator.pop(context); // Close library screen
          widget.onLoadChat?.call(chatId);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.2),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Add Chats Bottom Sheet
// ──────────────────────────────────────────────────────────
class _AddChatsBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> chats;

  const _AddChatsBottomSheet({required this.chats});

  @override
  State<_AddChatsBottomSheet> createState() => _AddChatsBottomSheetState();
}

class _AddChatsBottomSheetState extends State<_AddChatsBottomSheet> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Chats to Project',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, _selectedIds.toList()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9C63FF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Add (${_selectedIds.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Chat list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.chats.length,
              itemBuilder: (context, index) {
                final chat = widget.chats[index];
                final chatId = chat['id'] as String;
                final title = chat['title'] ?? 'Chat';
                final isSelected = _selectedIds.contains(chatId);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(chatId);
                      } else {
                        _selectedIds.add(chatId);
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C63FF)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? null
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
