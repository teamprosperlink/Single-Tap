import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../res/config/app_colors.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../services/group_chat_service.dart';
import '../../providers/other providers/app_providers.dart';
import '../../res/utils/photo_url_helper.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GroupChatService _groupChatService = GroupChatService();
  final ImagePicker _imagePicker = ImagePicker();

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);

  // Message pagination
  static const int _messagesPerPage = 50;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  bool _isSending = false;
  String _currentGroupName = '';
  String? _groupPhoto;
  Map<String, String> _memberNames = {};
  Map<String, String?> _memberPhotos = {};
  List<String> _admins = [];
  String? _createdBy;
  bool _isAdmin = false;

  // Optimistic messages (shown immediately before server confirms)
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Typing indicator
  List<String> _typingUsers = [];

  // Emoji picker
  bool _showEmojiPicker = false;
  final FocusNode _messageFocusNode = FocusNode();

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Reply
  Map<String, dynamic>? _replyToMessage;

  // Scroll button
  bool _showScrollButton = false;

  // Chat theme - gradient colors for sent message bubbles (same as 1-to-1)
  String _currentTheme = 'default';
  static const Map<String, List<Color>> chatThemes =
      AppColors.chatThemeGradients;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentGroupName = widget.groupName;
    _groupChatService.markAsRead(widget.groupId);
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_scrollListener);
    _loadChatTheme();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final shouldShow =
        _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 500;
    if (shouldShow != _showScrollButton) {
      setState(() => _showScrollButton = shouldShow);
    }
  }

  Future<void> _loadChatTheme() async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final theme = data?['chatTheme'] as String?;
        if (theme != null && chatThemes.containsKey(theme)) {
          setState(() => _currentTheme = theme);
        }
      }
    } catch (e) {
      debugPrint('Error loading chat theme: $e');
    }
  }

  Future<void> _saveChatTheme(String theme) async {
    try {
      await _firestore.collection('conversations').doc(widget.groupId).update({
        'chatTheme': theme,
      });
      setState(() => _currentTheme = theme);
    } catch (e) {
      debugPrint('Error saving chat theme: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _messageFocusNode.dispose();
    // Clear typing status on dispose
    _groupChatService.clearTypingStatus(widget.groupId);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clear typing status when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _groupChatService.clearTypingStatus(widget.groupId);
    }
  }

  void _onScroll() {
    // Load more messages when scrolling to top
    if (_scrollController.position.pixels <= 100 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final query = _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_messagesPerPage);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() => _hasMoreMessages = false);
      } else {
        _lastDocument = snapshot.docs.last;
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Clear input immediately
    _messageController.clear();
    final replyTo = _replyToMessage;
    setState(() => _replyToMessage = null);

    // Add optimistic message
    final optimisticMessage = {
      'id': 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': currentUserId,
      'text': text,
      'timestamp': Timestamp.now(),
      'isSystemMessage': false,
      'isOptimistic': true,
      'replyToMessageId': replyTo?['id'],
    };

    setState(() {
      _optimisticMessages.add(optimisticMessage);
      _isSending = true;
    });

    // Scroll to bottom for new message
    _scrollToBottom();

    // Clear typing status
    _groupChatService.setTyping(widget.groupId, false);

    try {
      final messageId = await _groupChatService.sendMessage(
        groupId: widget.groupId,
        text: text,
        replyToMessageId: replyTo?['id'],
      );

      if (messageId != null && mounted) {
        // Remove optimistic message (real one will come from stream)
        setState(() {
          _optimisticMessages.removeWhere(
            (m) => m['id'] == optimisticMessage['id'],
          );
        });
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove failed optimistic message
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere(
            (m) => m['id'] == optimisticMessage['id'],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Toggle search mode
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  // Show attachment options (like WhatsApp)
  void _showAttachmentOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      debugPrint('Opening gallery picker...');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        debugPrint('Image selected: ${image.path}');
        await _sendImageMessage(File(image.path));
      } else {
        debugPrint('No image selected');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  // Take photo with camera
  Future<void> _takePhoto() async {
    try {
      debugPrint('Opening camera...');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null) {
        debugPrint('Photo taken: ${image.path}');
        await _sendImageMessage(File(image.path));
      } else {
        debugPrint('No photo taken');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to take photo: $e')));
      }
    }
  }

  // Send image message
  Future<void> _sendImageMessage(File imageFile) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      debugPrint('Error: No authenticated user');
      return;
    }

    debugPrint('Starting image upload...');
    setState(() => _isSending = true);

    try {
      // Upload image to Firebase Storage
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.jpg';
      final ref = _storage.ref().child('chat_media/$currentUserId/$fileName');
      debugPrint('Uploading to: chat_media/$currentUserId/$fileName');

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      if (!mounted) return;
      final imageUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Image uploaded, URL: $imageUrl');

      if (!mounted) return;

      // Send message directly to Firestore (same as 1-to-1 chat)
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'text': '',
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isSystemMessage': false,
            'readBy': [currentUserId],
            if (_replyToMessage != null)
              'replyToMessageId': _replyToMessage!['id'],
          });

      // Update conversation
      await _firestore.collection('conversations').doc(widget.groupId).update({
        'lastMessage': ' Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      debugPrint('Image message sent successfully');
      if (mounted) {
        setState(() => _replyToMessage = null);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // Show chat theme picker
  void _showThemePicker() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Chat Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: chatThemes.entries.map((entry) {
                final isSelected = _currentTheme == entry.key;
                return GestureDetector(
                  onTap: () {
                    _saveChatTheme(entry.key);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: entry.value,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: entry.value[0].withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  // Show message options on long press
  void _showMessageOptions(Map<String, dynamic> message, bool isMe) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Reply option
              ListTile(
                leading: Icon(
                  Icons.reply,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  'Reply',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyToMessage = message);
                },
              ),
              // Copy option (only for text messages)
              if (message['text'] != null &&
                  (message['text'] as String).isNotEmpty)
                ListTile(
                  leading: Icon(
                    Icons.copy,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  title: Text(
                    'Copy',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message['text']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              // Delete option (only for own messages)
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Message?'),
                        content: const Text(
                          'This message will be deleted for everyone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _deleteMessage(message['id']);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show chat info/options
  void _showChatOptions() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.palette,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  'Chat Theme',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showThemePicker();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
                title: Text(
                  'Search Messages',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSearch();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
                title: Text(
                  'Group Info',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupInfo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGroupInfoSheet(),
    );
  }

  Widget _buildGroupInfoSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.15),
                      backgroundImage: PhotoUrlHelper.isValidUrl(_groupPhoto)
                          ? CachedNetworkImageProvider(_groupPhoto!)
                          : null,
                      child: !PhotoUrlHelper.isValidUrl(_groupPhoto)
                          ? Icon(
                              Icons.group,
                              color: Theme.of(context).primaryColor,
                              size: 32,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentGroupName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            '${_memberNames.length} members',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[600]
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    // Only show Add button if user is admin
                    if (_isAdmin)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddMembersSheet();
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _groupChatService.getGroupMembers(widget.groupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final members = snapshot.data!;
                    final currentUserId = _currentUserId;

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final memberId = member['id'] as String;
                        final isAdmin = member['isAdmin'] ?? false;
                        final isCreator = member['isCreator'] ?? false;
                        final isCurrentUser = memberId == currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                PhotoUrlHelper.isValidUrl(member['photoUrl'])
                                ? CachedNetworkImageProvider(member['photoUrl'])
                                : null,
                            child:
                                !PhotoUrlHelper.isValidUrl(member['photoUrl'])
                                ? Text((member['name'] ?? 'U')[0].toUpperCase())
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${member['name'] ?? 'Unknown'}${isCurrentUser ? ' (You)' : ''}',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCreator)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Creator',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onLongPress: _isAdmin && !isCurrentUser && !isCreator
                              ? () => _showMemberOptions(member)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveGroup(),
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      label: const Text(
                        'Leave Group',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final memberId = member['id'] as String;
    final memberName = member['name'] ?? 'Unknown';
    final isAdmin = member['isAdmin'] ?? false;
    final isCreator = _currentUserId == _createdBy;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                memberName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            if (isCreator && !isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.blue,
                ),
                title: const Text('Make Admin'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final success = await _groupChatService.makeAdmin(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$memberName is now an admin')),
                    );
                  }
                },
              ),
            if (isCreator && isAdmin)
              ListTile(
                leading: const Icon(
                  Icons.remove_moderator,
                  color: Colors.orange,
                ),
                title: const Text('Remove Admin'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final success = await _groupChatService.removeAdmin(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$memberName is no longer an admin'),
                      ),
                    );
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text(
                'Remove from Group',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final parentContext = this.context;
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: parentContext,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member?'),
                    content: Text('Remove $memberName from this group?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final success = await _groupChatService.removeMember(
                    groupId: widget.groupId,
                    memberId: memberId,
                  );
                  if (success && mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$memberName removed from group')),
                    );
                  } else if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to remove member. Only the creator can remove admins.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddMembersSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedUsers = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.darkCard : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              'Add Members',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const Spacer(),
                            if (selectedUsers.isNotEmpty)
                              ElevatedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final navigator = Navigator.of(context);
                                  final success = await _groupChatService
                                      .addMembers(
                                        groupId: widget.groupId,
                                        newMemberIds: selectedUsers.toList(),
                                      );
                                  if (success && mounted) {
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Members added successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to add members. Only admins can add members.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Text('Add (${selectedUsers.length})'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('users').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final currentMembers = _memberNames.keys.toSet();
                            final users = snapshot.data!.docs
                                .where(
                                  (doc) => !currentMembers.contains(doc.id),
                                )
                                .toList();

                            if (users.isEmpty) {
                              return Center(
                                child: Text(
                                  'No more users to add',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final userData =
                                    users[index].data() as Map<String, dynamic>;
                                final userId = users[index].id;
                                final name = userData['name'] ?? 'Unknown';
                                final photoUrl = userData['photoUrl'];
                                final isSelected = selectedUsers.contains(
                                  userId,
                                );

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        PhotoUrlHelper.isValidUrl(photoUrl)
                                        ? CachedNetworkImageProvider(photoUrl)
                                        : null,
                                    child: !PhotoUrlHelper.isValidUrl(photoUrl)
                                        ? Text(name[0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context).primaryColor,
                                        )
                                      : Icon(
                                          Icons.circle_outlined,
                                          color: isDarkMode
                                              ? Colors.grey[600]
                                              : Colors.grey,
                                        ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedUsers.remove(userId);
                                      } else {
                                        selectedUsers.add(userId);
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _groupChatService.leaveGroup(widget.groupId);
      if (success && mounted) {
        Navigator.pop(context); // Close info sheet if open
        Navigator.pop(context); // Go back from chat
      }
    }
  }

  String _getTypingText() {
    if (_typingUsers.isEmpty) return '';

    final currentUserId = _currentUserId;
    final typingNames = _typingUsers
        .where((id) => id != currentUserId)
        .map((id) => _memberNames[id]?.split(' ').first ?? 'Someone')
        .toList();

    if (typingNames.isEmpty) return '';
    if (typingNames.length == 1) return '${typingNames[0]} is typing...';
    if (typingNames.length == 2) {
      return '${typingNames.join(' and ')} are typing...';
    }
    return '${typingNames.length} people are typing...';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _currentUserId;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
      appBar: _buildAppBar(isDarkMode, currentUserId),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar when searching
              if (_isSearching) _buildSearchBar(isDarkMode),
              // Messages list with pagination
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('conversations')
                      .doc(widget.groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .limitToLast(_messagesPerPage)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data?.docs ?? [];

                    if (messages.isNotEmpty) {
                      _lastDocument = messages.first;
                      _hasMoreMessages = messages.length >= _messagesPerPage;
                    }

                    // Combine real messages with optimistic messages
                    var allMessages = [
                      ...messages.map(
                        (doc) => {
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                        },
                      ),
                      ..._optimisticMessages,
                    ];

                    // Filter by search query
                    if (_searchQuery.isNotEmpty) {
                      allMessages = allMessages.where((msg) {
                        final text = msg['text'] as String? ?? '';
                        return text.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                      }).toList();
                    }

                    if (allMessages.isEmpty) {
                      return _buildEmptyState(isDarkMode);
                    }

                    _groupChatService.markAsRead(widget.groupId);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_isLoadingMore && !_isSearching) {
                        _scrollToBottom();
                      }
                    });

                    return Column(
                      children: [
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_hasMoreMessages &&
                            messages.length >= _messagesPerPage &&
                            !_isSearching)
                          TextButton(
                            onPressed: _loadMoreMessages,
                            child: Text(
                              'Load earlier messages',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: allMessages.length,
                            itemBuilder: (context, index) {
                              final messageData = allMessages[index];
                              final senderId =
                                  messageData['senderId'] as String;
                              final text = messageData['text'] as String? ?? '';
                              final imageUrl =
                                  messageData['imageUrl'] as String?;
                              final timestamp =
                                  messageData['timestamp'] as Timestamp?;
                              final isSystemMessage =
                                  messageData['isSystemMessage'] ?? false;
                              final isOptimistic =
                                  messageData['isOptimistic'] ?? false;
                              final isMe = senderId == currentUserId;
                              final readBy = List<String>.from(
                                messageData['readBy'] ?? [],
                              );
                              final replyToId =
                                  messageData['replyToMessageId'] as String?;

                              if (isSystemMessage) {
                                return _buildSystemMessage(text, isDarkMode);
                              }

                              return _buildMessageBubble(
                                messageData: messageData,
                                text: text,
                                imageUrl: imageUrl,
                                senderId: senderId,
                                isMe: isMe,
                                timestamp: timestamp,
                                isDarkMode: isDarkMode,
                                isOptimistic: isOptimistic,
                                readBy: readBy,
                                replyToId: replyToId,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Reply preview
              if (_replyToMessage != null) _buildReplyPreview(isDarkMode),
              // Message input
              _buildMessageInput(isDarkMode),
              // Emoji picker
              if (_showEmojiPicker) _buildEmojiPicker(isDarkMode),
            ],
          ),
          // Scroll to bottom button
          if (_showScrollButton) _buildScrollToBottomButton(isDarkMode),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, String? currentUserId) {
    return AppBar(
      backgroundColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDarkMode ? Colors.white : AppColors.iosBlue,
          size: 22,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSearching
          ? null
          : StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('conversations')
                  .doc(widget.groupId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  _currentGroupName = data['groupName'] ?? widget.groupName;
                  _groupPhoto = data['groupPhoto'];
                  _memberNames = Map<String, String>.from(
                    data['participantNames'] ?? {},
                  );
                  _memberPhotos = Map<String, String?>.from(
                    data['participantPhotos'] ?? {},
                  );
                  _admins = List<String>.from(data['admins'] ?? []);
                  _createdBy = data['createdBy'];
                  _isAdmin = _admins.contains(currentUserId);

                  final isTypingMap = Map<String, bool>.from(
                    data['isTyping'] ?? {},
                  );
                  _typingUsers = isTypingMap.entries
                      .where((e) => e.value == true && e.key != currentUserId)
                      .map((e) => e.key)
                      .toList();
                }

                final typingText = _getTypingText();

                return GestureDetector(
                  onTap: _showGroupInfo,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.15),
                        backgroundImage: PhotoUrlHelper.isValidUrl(_groupPhoto)
                            ? CachedNetworkImageProvider(_groupPhoto!)
                            : null,
                        child: !PhotoUrlHelper.isValidUrl(_groupPhoto)
                            ? Icon(
                                Icons.group,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGroupName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              typingText.isNotEmpty
                                  ? typingText
                                  : '${_memberNames.length} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: typingText.isNotEmpty
                                    ? Theme.of(context).primaryColor
                                    : (isDarkMode
                                          ? Colors.grey[600]
                                          : Colors.grey),
                                fontStyle: typingText.isNotEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
            ),
            onPressed: _toggleSearch,
          ),
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.more_horiz_rounded,
            color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
          ),
          onPressed: _isSearching ? _toggleSearch : _showChatOptions,
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDarkMode ? AppColors.darkCard : Colors.grey[100],
      child: GlassTextField(
        controller: _searchController,
        autofocus: true,
        hintText: 'Search messages...',
        prefixIcon: Icon(
          Icons.search,
          color: isDarkMode ? Colors.grey[600] : Colors.grey,
        ),
        borderRadius: 12,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.group,
            size: 80,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No messages found' : 'No messages yet',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search'
                : 'Start the conversation!',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(bool isDarkMode) {
    final senderName = _memberNames[_replyToMessage!['senderId']] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _replyToMessage!['text'] ?? 'Photo',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: isDarkMode ? Colors.grey[600] : Colors.grey,
            ),
            onPressed: () => setState(() => _replyToMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final themeColors = chatThemes[_currentTheme] ?? chatThemes['default']!;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: _showEmojiPicker
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.iosSystemGray,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? AppColors.iosGrayDark : AppColors.iosGrayLight,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          GestureDetector(
            onTap: _showAttachmentOptions,
            child: Container(
              height: 36,
              width: 36,
              margin: const EdgeInsets.only(bottom: 2, right: 4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.iosGrayDark
                    : AppColors.iosGrayLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.iosBlue,
                size: 22,
              ),
            ),
          ),
          // Camera button
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 36,
              width: 36,
              margin: const EdgeInsets.only(bottom: 2, right: 6),
              child: Icon(
                Icons.camera_alt_rounded,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                size: 24,
              ),
            ),
          ),
          // Message input field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.iosGrayDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.iosGraySecondary
                      : AppColors.iosGrayLight,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: GlassTextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      hintText: 'Message',
                      showBlur: false,
                      decoration: const BoxDecoration(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onChanged: (text) {
                        setState(() {});
                        _groupChatService.setTyping(
                          widget.groupId,
                          text.isNotEmpty,
                        );
                      },
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                    ),
                  ),
                  // Emoji button
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                          if (_showEmojiPicker) {
                            _messageFocusNode.unfocus();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _showEmojiPicker
                              ? AppColors.iosBlue.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker
                              ? AppColors.iosBlue
                              : AppColors.iosGray,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button with gradient
          GestureDetector(
            onTap: hasText ? _sendMessage : null,
            child: Container(
              height: 36,
              width: 36,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: hasText
                    ? LinearGradient(
                        colors: themeColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasText
                    ? null
                    : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                shape: BoxShape.circle,
                boxShadow: hasText
                    ? [
                        BoxShadow(
                          color: themeColors[0].withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: hasText ? Colors.white : Colors.grey,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker(bool isDarkMode) {
    final screenHeight = MediaQuery.of(context).size.height;
    final emojiPickerHeight = (screenHeight * 0.35).clamp(200.0, 350.0);

    return Container(
      height: emojiPickerHeight,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.iosSystemGray,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? AppColors.iosGrayDark : AppColors.iosGrayLight,
            width: 0.5,
          ),
        ),
      ),
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          _messageController.text += emoji.emoji;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
          setState(() {});
        },
        onBackspacePressed: () {
          _messageController.text = _messageController.text.characters
              .skipLast(1)
              .toString();
          setState(() {});
        },
        config: Config(
          height: emojiPickerHeight,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 32,
            backgroundColor: isDarkMode
                ? AppColors.backgroundDark
                : AppColors.iosSystemGray,
            recentsLimit: 28,
          ),
          categoryViewConfig: CategoryViewConfig(
            initCategory: Category.RECENT,
            backgroundColor: isDarkMode
                ? AppColors.backgroundDark
                : AppColors.iosSystemGray,
            indicatorColor: AppColors.iosBlue,
            iconColor: AppColors.iosGray,
            iconColorSelected: AppColors.iosBlue,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: isDarkMode
                ? AppColors.backgroundDark
                : AppColors.iosSystemGray,
            buttonColor: AppColors.iosBlue,
            buttonIconColor: Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDarkMode ? AppColors.iosGrayDark : Colors.white,
            buttonIconColor: AppColors.iosBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton(bool isDarkMode) {
    return Positioned(
      bottom: _showEmojiPicker ? 370 : 100,
      right: 16,
      child: GestureDetector(
        onTap: _scrollToBottom,
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.iosGrayDark : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(String text, bool isDarkMode) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required Map<String, dynamic> messageData,
    required String text,
    String? imageUrl,
    required String senderId,
    required bool isMe,
    Timestamp? timestamp,
    required bool isDarkMode,
    bool isOptimistic = false,
    List<String> readBy = const [],
    String? replyToId,
  }) {
    final senderName = _memberNames[senderId] ?? 'Unknown';
    final senderPhoto = _memberPhotos[senderId];
    final totalMembers = _memberNames.length;
    final readCount = readBy.length;
    final themeColors = chatThemes[_currentTheme] ?? chatThemes['default']!;
    final hasContent = text.isNotEmpty || imageUrl != null;

    if (!hasContent) return const SizedBox.shrink();

    return GestureDetector(
      onLongPress: () => _showMessageOptions(messageData, isMe),
      child: Opacity(
        opacity: isOptimistic ? 0.7 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundImage: PhotoUrlHelper.isValidUrl(senderPhoto)
                      ? CachedNetworkImageProvider(senderPhoto!)
                      : null,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1),
                  child: !PhotoUrlHelper.isValidUrl(senderPhoto)
                      ? Text(
                          senderName.isNotEmpty
                              ? senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: themeColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isMe
                            ? null
                            : (isDarkMode
                                  ? AppColors.iosGrayDark
                                  : AppColors.iosGrayTertiary),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply preview
                          if (replyToId != null)
                            _buildReplyBubble(replyToId, isMe, isDarkMode),
                          // Image
                          if (imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: text.isEmpty
                                    ? Radius.circular(isMe ? 18 : 4)
                                    : Radius.zero,
                                bottomRight: text.isEmpty
                                    ? Radius.circular(isMe ? 4 : 18)
                                    : Radius.zero,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 200,
                                  height: 150,
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
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                    ),
                              ),
                            ),
                          // Text
                          if (text.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                left: 14,
                                right: 14,
                                top: imageUrl != null ? 8 : 10,
                                bottom: 4,
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : (isDarkMode
                                            ? Colors.white
                                            : AppColors.iosGrayDark),
                                  fontSize: 16,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          // Timestamp and read status
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 14,
                              right: 14,
                              bottom: 8,
                              top: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (timestamp != null)
                                  Text(
                                    DateFormat(
                                      'h:mm a',
                                    ).format(timestamp.toDate()),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : (isDarkMode
                                                ? Colors.grey[500]
                                                : Colors.grey[600]),
                                    ),
                                  ),
                                if (isMe && !isOptimistic) ...[
                                  const SizedBox(width: 4),
                                  if (readCount >= totalMembers)
                                    const Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: AppColors.iosGreen,
                                    )
                                  else if (readCount > 1)
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.done,
                                      size: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                ],
                                if (isOptimistic) ...[
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: isMe
                                          ? Colors.white70
                                          : (isDarkMode
                                                ? Colors.grey[600]
                                                : Colors.grey),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBubble(String messageId, bool isMe, bool isDarkMode) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final replyData = snapshot.data!.data() as Map<String, dynamic>?;
        if (replyData == null) return const SizedBox.shrink();

        final replySenderName =
            _memberNames[replyData['senderId']] ?? 'Unknown';

        return Container(
          margin: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isMe ? Colors.white : Theme.of(context).primaryColor)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isMe ? Colors.white70 : Theme.of(context).primaryColor,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replySenderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              Text(
                replyData['text'] ?? ' Photo',
                style: TextStyle(
                  fontSize: 12,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
