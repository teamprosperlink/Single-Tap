import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../../res/config/app_colors.dart';
import '../../res/config/app_assets.dart';
import '../../widgets/other widgets/glass_text_field.dart';
import '../../services/group_chat_service.dart';
import '../../providers/other providers/app_providers.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../services/notification_service.dart';
import '../../res/utils/snackbar_helper.dart';
import '../call/group_audio_call_screen.dart';
import '../call/group_video_call_screen.dart';
import 'media_gallery_screen.dart';
import 'group_info_screen.dart';

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
  bool _isRecordingVideo = false;
  String _currentGroupName = '';
  String? _groupPhoto;
  Map<String, String> _memberNames = {};
  Map<String, String?> _memberPhotos = {};

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

  // Edit
  Map<String, dynamic>? _editingMessage;

  // Multi-select mode
  bool _isMultiSelectMode = false;
  final Set<String> _selectedMessageIds = {};

  // Scroll button
  bool _showScrollButton = false;

  // Chat theme - gradient colors for sent message bubbles (same as 1-to-1)
  String _currentTheme = 'default';
  static const Map<String, List<Color>> chatThemes =
      AppColors.chatThemeGradients;

  // Voice recording variables - lazy initialized to prevent crashes
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Voice playback variables - lazy initialized to prevent crashes
  FlutterSoundPlayer? _audioPlayer;
  bool _isPlayerInitialized = false;

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
    // Clean up audio resources
    _recordingTimer?.cancel();
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
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
    // If in edit mode, save the edited message instead
    if (_editingMessage != null) {
      await _saveEditedMessage();
      return;
    }

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

  // Open media gallery
  void _openMediaGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          conversationId: widget.groupId,
          otherUserName: _currentGroupName.isNotEmpty
              ? _currentGroupName
              : widget.groupName,
        ),
      ),
    );
  }

  // Start group audio call
  Future<void> _startGroupAudioCall() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      // Get group members
      final members = await _groupChatService.getGroupMembers(widget.groupId);

      // Create participants list (excluding current user for the call initiation)
      final participants = members
          .where((member) => member['id'] != currentUserId)
          .map(
            (member) => {
              'userId': member['id'] as String,
              'name': member['name'] ?? 'Unknown',
              'photoUrl': member['photoUrl'],
            },
          )
          .toList();

      if (participants.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No members to call')));
        }
        return;
      }

      // Create call document
      final callDoc = await _firestore.collection('group_calls').add({
        'groupId': widget.groupId,
        'callerId': currentUserId,
        'callerName': _memberNames[currentUserId] ?? 'Unknown',
        'participants': members.map((m) => m['id']).toList(),
        'isVideo': false,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notifications to all participants
      for (final participant in participants) {
        NotificationService().sendNotificationToUser(
          userId: participant['userId'] as String,
          title: 'Incoming Group Call',
          body:
              '${_memberNames[currentUserId] ?? 'Someone'} is calling ${widget.groupName}',
          type: 'group_audio_call',
          data: {
            'callId': callDoc.id,
            'groupId': widget.groupId,
            'groupName': widget.groupName,
            'callerId': currentUserId,
            'isVideo': false,
          },
        );
      }

      // Navigate to group audio call screen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupAudioCallScreen(
              callId: callDoc.id,
              userId: currentUserId,
              userName: _memberNames[currentUserId] ?? 'You',
              participants: [
                {
                  'userId': currentUserId,
                  'name': _memberNames[currentUserId] ?? 'You',
                  'photoUrl': _memberPhotos[currentUserId],
                },
                ...participants,
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting group audio call: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    }
  }

  // Start group video call
  Future<void> _startGroupVideoCall() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      // Get group members
      final members = await _groupChatService.getGroupMembers(widget.groupId);

      // Create participants list (excluding current user for the call initiation)
      final participants = members
          .where((member) => member['id'] != currentUserId)
          .map(
            (member) => {
              'userId': member['id'] as String,
              'name': member['name'] ?? 'Unknown',
              'photoUrl': member['photoUrl'],
            },
          )
          .toList();

      if (participants.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No members to call')));
        }
        return;
      }

      // Create call document
      final callDoc = await _firestore.collection('group_calls').add({
        'groupId': widget.groupId,
        'callerId': currentUserId,
        'callerName': _memberNames[currentUserId] ?? 'Unknown',
        'participants': members.map((m) => m['id']).toList(),
        'isVideo': true,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notifications to all participants
      for (final participant in participants) {
        NotificationService().sendNotificationToUser(
          userId: participant['userId'] as String,
          title: 'Incoming Group Video Call',
          body:
              '${_memberNames[currentUserId] ?? 'Someone'} is video calling ${widget.groupName}',
          type: 'group_video_call',
          data: {
            'callId': callDoc.id,
            'groupId': widget.groupId,
            'groupName': widget.groupName,
            'callerId': currentUserId,
            'isVideo': true,
          },
        );
      }

      // Navigate to group video call screen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupVideoCallScreen(
              callId: callDoc.id,
              userId: currentUserId,
              userName: _memberNames[currentUserId] ?? 'You',
              participants: [
                {
                  'userId': currentUserId,
                  'name': _memberNames[currentUserId] ?? 'You',
                  'photoUrl': _memberPhotos[currentUserId],
                },
                ...participants,
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting group video call: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    }
  }

  // Show attachment options (like Enhanced Chat)
  void _showAttachmentOptions() {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping on popup
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera Photo option
                      _buildPopupOption(
                        icon: Icons.camera_alt,
                        label: 'Take Photo',
                        onTap: () {
                          Navigator.pop(context);
                          _takePhoto();
                        },
                      ),
                      // Camera Video option
                      _buildPopupOption(
                        icon: Icons.videocam,
                        label: 'Record Video',
                        onTap: () {
                          Navigator.pop(context);
                          _recordVideo();
                        },
                      ),
                      // Gallery Photo option
                      _buildPopupOption(
                        icon: Icons.image,
                        label: 'Photo from Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      // Gallery Video option
                      _buildPopupOption(
                        icon: Icons.video_library,
                        label: 'Video from Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
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

  // Record video from camera
  void _recordVideo() async {
    if (_isRecordingVideo) return;
    _isRecordingVideo = true;

    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Camera permission required to record video',
          );
        }
        return;
      }

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _isRecordingVideo = false;
        if (mounted) {
          SnackBarHelper.showError(context, 'Microphone permission required');
        }
        return;
      }

      if (!mounted) {
        _isRecordingVideo = false;
        return;
      }

      final video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );

      _isRecordingVideo = false;

      if (video != null && mounted) {
        final videoFile = File(video.path);
        final fileSize = await videoFile.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 25) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video too large (${fileSizeMB.toStringAsFixed(1)}MB). Max 25MB.',
            );
          }
          return;
        }

        await _sendVideoMessage(videoFile);
      }
    } catch (e) {
      _isRecordingVideo = false;
      debugPrint('Error recording video: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to record video');
      }
    }
  }

  // Pick video from gallery
  void _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);

      if (video != null && mounted) {
        final videoFile = File(video.path);
        final fileSize = await videoFile.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        if (fileSizeMB > 25) {
          if (mounted) {
            SnackBarHelper.showError(
              context,
              'Video too large (${fileSizeMB.toStringAsFixed(1)}MB). Max 25MB.',
            );
          }
          return;
        }

        await _sendVideoMessage(videoFile);
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to pick video');
      }
    }
  }

  // Send video message
  Future<void> _sendVideoMessage(File videoFile) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    setState(() => _isSending = true);

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.mp4';
      final ref = _storage.ref().child('chat_media/$currentUserId/$fileName');

      final uploadTask = ref.putFile(videoFile);
      final snapshot = await uploadTask;

      if (!mounted) return;
      final videoUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;

      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'text': '',
            'videoUrl': videoUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isSystemMessage': false,
            'readBy': [currentUserId],
            if (_replyToMessage != null)
              'replyToMessageId': _replyToMessage!['id'],
          });

      await _firestore.collection('conversations').doc(widget.groupId).update({
        'lastMessage': '🎥 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      if (mounted) {
        setState(() => _replyToMessage = null);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending video: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send video');
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

  // ==================== EDIT MESSAGE METHODS ====================

  void _editMessage(Map<String, dynamic> message) {
    setState(() {
      // Clear reply first - only one action at a time
      _replyToMessage = null;
      _editingMessage = message;
      _messageController.text = message['text'] ?? '';
    });
    FocusScope.of(context).requestFocus(_messageFocusNode);
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _saveEditedMessage() async {
    if (_editingMessage == null || _messageController.text.trim().isEmpty) {
      return;
    }

    final newText = _messageController.text.trim();
    final messageId = _editingMessage!['id'];

    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });

    try {
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving edited message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to edit message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== MULTI-SELECT MODE METHODS ====================

  void _enterMultiSelectMode(String initialMessageId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(initialMessageId);
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        // Exit multi-select if no messages selected
        if (_selectedMessageIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Check if all selected messages are from current user
    bool allMyMessages = true;
    try {
      for (final messageId in _selectedMessageIds) {
        final doc = await _firestore
            .collection('conversations')
            .doc(widget.groupId)
            .collection('messages')
            .doc(messageId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          if (data['senderId'] != currentUserId) {
            allMyMessages = false;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking message ownership: $e');
      allMyMessages = false;
    }

    final result = await _showDeleteDialog(
      title:
          'Delete ${_selectedMessageIds.length} message${_selectedMessageIds.length > 1 ? 's' : ''}?',
      showDeleteForEveryone: allMyMessages,
    );

    if (result == null) return;

    if (result == 'for_me') {
      for (final messageId in _selectedMessageIds.toList()) {
        await _deleteMessageForMe(messageId);
      }
      _exitMultiSelectMode();
    } else if (result == 'for_everyone') {
      for (final messageId in _selectedMessageIds.toList()) {
        await _deleteMessageForEveryone(messageId);
      }
      _exitMultiSelectMode();
    }
  }

  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    // Get selected messages data
    final List<Map<String, dynamic>> selectedMessages = [];

    try {
      for (final messageId in _selectedMessageIds) {
        final doc = await _firestore
            .collection('conversations')
            .doc(widget.groupId)
            .collection('messages')
            .doc(messageId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          data['id'] = doc.id;
          selectedMessages.add(data);
        }
      }

      if (selectedMessages.isEmpty) {
        return;
      }

      // Show forward screen
      final result = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _ForwardMessageScreen(currentUserId: _currentUserId!),
        ),
      );

      if (result != null && result.isNotEmpty && mounted) {
        // Forward each selected message to each selected recipient
        for (final recipient in result) {
          for (final message in selectedMessages) {
            try {
              await _sendForwardedMessage(recipient, message);
            } catch (e) {
              debugPrint('Failed to forward message: $e');
            }
          }
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Message${selectedMessages.length > 1 ? 's' : ''} forwarded to ${result.length} contact${result.length > 1 ? 's' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Exit multi-select mode
        _exitMultiSelectMode();
      }
    } catch (e) {
      debugPrint('Error forwarding messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to forward messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== FORWARD MESSAGE METHODS ====================

  Future<void> _forwardMessage(Map<String, dynamic> message) async {
    try {
      // Show forward screen
      final result = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _ForwardMessageScreen(currentUserId: _currentUserId!),
        ),
      );

      if (result != null && result.isNotEmpty && mounted) {
        // Forward message to each selected recipient
        for (final recipient in result) {
          try {
            await _sendForwardedMessage(recipient, message);
          } catch (e) {
            debugPrint('Failed to forward message: $e');
          }
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Message forwarded to ${result.length} contact${result.length > 1 ? 's' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error forwarding message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to forward message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendForwardedMessage(
    Map<String, dynamic> recipient,
    Map<String, dynamic> originalMessage,
  ) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      final recipientId = recipient['uid'] as String;

      // Get or create conversation with recipient
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      String? conversationId;

      // Find existing conversation with recipient
      for (final doc in conversationsSnapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(recipientId) && participants.length == 2) {
          conversationId = doc.id;
          break;
        }
      }

      // Create new conversation if doesn't exist
      if (conversationId == null) {
        final newConvDoc = await _firestore.collection('conversations').add({
          'participants': [currentUserId, recipientId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUserId,
          'unreadCount': {currentUserId: 0, recipientId: 1},
        });
        conversationId = newConvDoc.id;
      }

      // Prepare forwarded message
      final forwardedText = originalMessage['text'] as String?;
      final imageUrl = originalMessage['imageUrl'] as String?;
      final audioUrl = originalMessage['audioUrl'] as String?;

      // Send message to new conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'receiverId': recipientId,
            'text': forwardedText,
            'imageUrl': imageUrl,
            'audioUrl': audioUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'isRead': false,
            'isForwarded': true, // Mark as forwarded
          });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage':
            forwardedText ??
            (imageUrl != null
                ? '📷 Photo'
                : (audioUrl != null ? '🎵 Audio' : '')),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'unreadCount.$recipientId': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Failed to forward message: $e');
      rethrow;
    }
  }

  // Show message options on long press
  void _showMessageOptions(Map<String, dynamic> message, bool isMe) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMessageOption(
                        icon: Icons.reply,
                        label: 'Reply',
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _replyToMessage = message);
                        },
                      ),
                      _buildMessageOption(
                        icon: Icons.forward,
                        label: 'Forward',
                        onTap: () {
                          Navigator.pop(context);
                          _forwardMessage(message);
                        },
                      ),
                      if (message['text'] != null &&
                          (message['text'] as String).isNotEmpty)
                        _buildMessageOption(
                          icon: Icons.copy,
                          label: 'Copy',
                          onTap: () {
                            Navigator.pop(context);
                            Clipboard.setData(
                              ClipboardData(text: message['text']),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          },
                        ),
                      if (isMe &&
                          message['text'] != null &&
                          (message['text'] as String).isNotEmpty)
                        _buildMessageOption(
                          icon: Icons.edit,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(context);
                            _editMessage(message);
                          },
                        ),
                      _buildMessageOption(
                        icon: Icons.check_circle_outline,
                        label: 'Select',
                        onTap: () {
                          Navigator.pop(context);
                          _enterMultiSelectMode(message['id']);
                        },
                      ),
                      _buildMessageOption(
                        icon: Icons.delete,
                        label: 'Delete',
                        isDestructive: true,
                        onTap: () async {
                          Navigator.pop(context);
                          await _deleteMessage(message['id'], isMe);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 24,
              ),
              const SizedBox(width: 20),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DELETE MESSAGE METHODS ====================

  /// Show WhatsApp-style delete dialog with glass effect
  Future<String?> _showDeleteDialog({
    required String title,
    required bool showDeleteForEveryone,
  }) async {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how to delete',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (showDeleteForEveryone) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context, 'for_everyone'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.redAccent,
                        ),
                        child: const Center(
                          child: Text(
                            'Delete for everyone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white.withValues(alpha: 0.15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, 'for_me'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.redAccent,
                            ),
                            child: const Center(
                              child: Text(
                                'Delete for me',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Delete message for me only (adds to deletedFor array)
  Future<void> _deleteMessageForMe(String messageId) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      // Add current user to deletedFor array (message is hidden only for this user)
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          });
    } catch (e) {
      debugPrint('Error deleting message for me: $e');
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

  /// Delete message for everyone - WhatsApp style "This message was deleted"
  Future<void> _deleteMessageForEveryone(String messageId) async {
    try {
      // Get the message first to check for media
      final messageDoc = await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;

      // Delete media from Firebase Storage if exists
      final imageUrl = messageData['imageUrl'] as String?;
      final audioUrl = messageData['audioUrl'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting image file: $e');
        }
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(audioUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting audio file: $e');
        }
      }

      // Mark message as deleted (WhatsApp style - shows "This message was deleted")
      await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
            'isDeleted': true,
            'text': 'This message was deleted',
            'imageUrl': null,
            'audioUrl': null,
            'deletedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
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

  /// Show delete dialog and handle deletion
  Future<void> _deleteMessage(String messageId, bool isMyMessage) async {
    final result = await _showDeleteDialog(
      title: 'Delete Message',
      showDeleteForEveryone: isMyMessage,
    );

    if (result == 'for_me') {
      await _deleteMessageForMe(messageId);
    } else if (result == 'for_everyone') {
      await _deleteMessageForEveryone(messageId);
    }
  }

  void _showGroupInfo() async {
    debugPrint('=== _showGroupInfo called ===');
    final currentUserId = _currentUserId;
    debugPrint('Current user ID: $currentUserId');

    if (currentUserId == null) {
      debugPrint('Current user ID is null, returning');
      return;
    }

    try {
      debugPrint('Fetching group data for: ${widget.groupId}');
      // Fetch the latest group data from Firestore
      final groupDoc = await _firestore
          .collection('conversations')
          .doc(widget.groupId)
          .get();

      debugPrint('Group doc exists: ${groupDoc.exists}');

      if (!groupDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Group not found')));
        }
        return;
      }

      final groupData = groupDoc.data()!;
      final memberIds = List<String>.from(groupData['participants'] ?? []);
      final groupName = groupData['groupName'] ?? _currentGroupName;
      final groupPhoto = groupData['groupPhoto'] ?? _groupPhoto;

      debugPrint('Group name: $groupName');
      debugPrint('Member IDs: $memberIds');
      debugPrint('Member count: ${memberIds.length}');

      if (mounted) {
        debugPrint('Navigating to GroupInfoScreen...');
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupInfoScreen(
              groupId: widget.groupId,
              groupName: groupName,
              groupPhoto: groupPhoto,
              memberIds: memberIds,
            ),
          ),
        );

        debugPrint('Returned from GroupInfoScreen with result: $result');

        // Handle result if search was requested
        if (result == 'search' && mounted) {
          _toggleSearch();
        } else if (result == 'theme' && mounted) {
          _showThemePicker();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error opening group info: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group info: $e')),
        );
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
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDarkMode, currentUserId),
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
            child: Container(color: AppColors.darkOverlay(alpha: 0.8)),
          ),
          // Content
          SafeArea(
            child: Column(
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

                      // Filter out messages deleted for current user
                      allMessages = allMessages.where((msg) {
                        final deletedFor = msg['deletedFor'] as List<dynamic>?;
                        if (deletedFor != null &&
                            deletedFor.contains(currentUserId)) {
                          return false; // Hide message for this user
                        }
                        return true;
                      }).toList();

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                final text =
                                    messageData['text'] as String? ?? '';
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
                // Edit preview
                if (_editingMessage != null) _buildEditPreview(isDarkMode),
                // Message input
                _buildMessageInput(isDarkMode),
                // Emoji picker
                if (_showEmojiPicker) _buildEmojiPicker(isDarkMode),
              ],
            ),
          ),
          // Scroll to bottom button
          if (_showScrollButton) _buildScrollToBottomButton(isDarkMode),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, String? currentUserId) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          height: 0.5,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          _isMultiSelectMode ? Icons.close : Icons.arrow_back_ios_rounded,
          color: isDarkMode ? Colors.white : AppColors.iosBlue,
          size: 22,
        ),
        onPressed: () {
          if (_isMultiSelectMode) {
            _exitMultiSelectMode();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: _isMultiSelectMode
          ? Text(
              '${_selectedMessageIds.length} selected',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            )
          : _isSearching
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
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.15),
                          backgroundImage:
                              PhotoUrlHelper.isValidUrl(_groupPhoto)
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
        if (_isMultiSelectMode) ...[
          // Forward button
          IconButton(
            icon: Icon(
              Icons.forward,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _selectedMessageIds.isNotEmpty
                ? _forwardSelectedMessages
                : null,
            tooltip: 'Forward',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 24),
            onPressed: _selectedMessageIds.isNotEmpty
                ? _deleteSelectedMessages
                : null,
            tooltip: 'Delete',
          ),
        ] else if (!_isSearching) ...[
          // Video call button
          IconButton(
            icon: Icon(
              Icons.videocam_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startGroupVideoCall,
            tooltip: 'Video Call',
          ),
          // Audio call button
          IconButton(
            icon: Icon(
              Icons.call_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _startGroupAudioCall,
            tooltip: 'Voice Call',
          ),
        ],
        if (!_isMultiSelectMode)
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.more_vert_rounded,
              color: isDarkMode ? Colors.white70 : AppColors.iosBlue,
              size: 24,
            ),
            onPressed: _isSearching ? _toggleSearch : _showGroupInfo,
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

  Widget _buildEditPreview(bool isDarkMode) {
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
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _editingMessage!['text'] ?? '',
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
            onPressed: _cancelEdit,
          ),
        ],
      ),
    );
  }

  // Voice recording methods
  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            'Microphone permission is required for voice messages',
          );
        }
        return;
      }

      // Initialize recorder if not already
      if (!_isRecorderInitialized || _audioRecorder == null) {
        try {
          _audioRecorder = FlutterSoundRecorder();
          await _audioRecorder!.openRecorder();
          _isRecorderInitialized = true;
        } catch (e) {
          debugPrint('Error opening recorder: $e');
          if (mounted) {
            SnackBarHelper.showError(context, 'Failed to initialize recorder');
          }
          return;
        }
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_message_$timestamp.aac';

      // Start recording with optimized bitrate for faster upload
      await _audioRecorder!.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacADTS,
        bitRate: 64000, // 64kbps - good quality voice, smaller file size
        sampleRate: 22050, // 22kHz - sufficient for voice
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer to track duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to start recording');
      }
    }
  }

  Future<void> _showVoiceRecordingPopup() async {
    // Stop the timer but keep recording state
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = _recordingDuration;

    // Stop recorder and get path safely
    String? path;
    try {
      path = await _audioRecorder?.stopRecorder();
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
    }

    if (path == null || path.isEmpty) return;

    // Store non-nullable reference for use in closures
    final audioPath = path;

    // Initialize player if needed
    _audioPlayer ??= FlutterSoundPlayer();

    // Show small centered popup with audio preview
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _VoicePreviewPopup(
        audioPath: audioPath,
        duration: duration,
        audioPlayer: _audioPlayer!,
        isPlayerInitialized: _isPlayerInitialized,
        onInitializePlayer: () async {
          if (!_isPlayerInitialized && _audioPlayer != null) {
            await _audioPlayer!.openPlayer();
            await _audioPlayer!.setSubscriptionDuration(
              const Duration(milliseconds: 100),
            );
            _isPlayerInitialized = true;
          }
        },
        onSend: () async {
          Navigator.pop(context);
          await _sendVoiceMessage(audioPath, duration);
        },
        onCancel: () {
          Navigator.pop(context);
          try {
            File(audioPath).deleteSync();
          } catch (_) {}
        },
      ),
    );
  }

  String _formatRecordingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendVoiceMessage(String filePath, int audioDuration) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          SnackBarHelper.showError(context, 'Recording file not found');
        }
        return;
      }

      // Upload to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_${currentUserId}_$timestamp.aac';
      final storageRef = _storage
          .ref()
          .child('voice_messages')
          .child(widget.groupId)
          .child(fileName);

      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      final snapshot = await uploadTask;
      final audioUrl = await snapshot.ref.getDownloadURL();

      // Send voice message to group
      await _groupChatService.sendMessage(
        groupId: widget.groupId,
        text: '',
        voiceUrl: audioUrl,
        voiceDuration: audioDuration,
      );

      // Delete local file
      await file.delete();

      // Scroll to bottom
      _scrollToBottom();

      // Reset recording duration
      _recordingDuration = 0;
    } catch (e) {
      debugPrint('Error sending voice message: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to send voice message');
      }
    }
  }

  Widget _buildMessageInput(bool isDarkMode) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final themeColors = chatThemes[_currentTheme] ?? chatThemes['default']!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // White border line at the top
        Container(height: 0.5, color: Colors.white),
        // Input Area - Premium iMessage style
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: _showEmojiPicker
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button - Camera/Gallery options
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    height: 48,
                    width: 48,
                    margin: const EdgeInsets.only(bottom: 0, right: 8),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.add_circle,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 40,
                    ),
                  ),
                ),
                // Message input field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
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
                          padding: const EdgeInsets.only(right: 4, bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                                if (_showEmojiPicker) {
                                  _messageFocusNode.unfocus();
                                } else {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_messageFocusNode);
                                }
                              });
                            },
                            child: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_rounded
                                  : Icons.emoji_emotions_outlined,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send / Mic button - Premium animated
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                  child: hasText
                      ? GestureDetector(
                          key: const ValueKey('send'),
                          onTap: _sendMessage,
                          child: Container(
                            height: 36,
                            width: 36,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: themeColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: themeColors[0].withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                    _editingMessage != null
                                        ? Icons.check_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        )
                      : GestureDetector(
                          key: const ValueKey('mic'),
                          // Tap to toggle recording
                          onTap: () async {
                            if (_isRecording) {
                              // Show confirmation popup
                              await _showVoiceRecordingPopup();
                            } else {
                              // Start recording
                              await _startRecording();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 42,
                            width: _isRecording ? 90 : 42,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                              boxShadow: _isRecording
                                  ? [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: _isRecording
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Recording timer
                                        Text(
                                          _formatRecordingTime(
                                            _recordingDuration,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 1),
                                        // Stop icon
                                        const Icon(
                                          Icons.stop_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.mic_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      size: 28,
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
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

    final messageId = messageData['id'] as String;
    final isSelected = _selectedMessageIds.contains(messageId);

    return GestureDetector(
      onTap: _isMultiSelectMode
          ? () => _toggleMessageSelection(messageId)
          : null,
      onLongPress: () => _showMessageOptions(messageData, isMe),
      child: Opacity(
        opacity: isOptimistic ? 0.7 : 1.0,
        child: Container(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Selection checkbox
              if (_isMultiSelectMode) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? Colors.blue : Colors.grey,
                    size: 24,
                  ),
                ),
              ],
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
                        // Only show gradient/color background if there's text
                        // For image-only messages, use transparent background
                        gradient: (isMe && text.isNotEmpty)
                            ? LinearGradient(
                                colors: themeColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: (!isMe && text.isNotEmpty)
                            ? (isDarkMode
                                  ? AppColors.iosGrayDark
                                  : AppColors.iosGrayTertiary)
                            : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        boxShadow: text.isNotEmpty
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply preview
                          if (replyToId != null)
                            _buildReplyBubble(replyToId, isMe, isDarkMode),
                          // Image
                          if (imageUrl != null)
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.iosBlue,
                                  width: 2,
                                ),
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
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: text.isEmpty
                                      ? Radius.circular(isMe ? 16 : 2)
                                      : Radius.zero,
                                  bottomRight: text.isEmpty
                                      ? Radius.circular(isMe ? 2 : 16)
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
                                  color: (messageData['isDeleted'] == true)
                                      ? Colors.grey
                                      : (isMe
                                            ? Colors.white
                                            : (isDarkMode
                                                  ? Colors.white
                                                  : AppColors.iosGrayDark)),
                                  fontSize: 16,
                                  height: 1.35,
                                  fontStyle: (messageData['isDeleted'] == true)
                                      ? FontStyle.italic
                                      : FontStyle.normal,
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : (isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600]),
                                    ),
                                  ),
                                if (isMe && !isOptimistic) ...[
                                  const SizedBox(width: 4),
                                  if (readCount >= totalMembers)
                                    const Icon(
                                      Icons.done_all,
                                      size: 16,
                                      color: AppColors.iosGreen,
                                    )
                                  else if (readCount > 1)
                                    Icon(
                                      Icons.done_all,
                                      size: 16,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.done,
                                      size: 16,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
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

// Voice Preview Popup Widget
class _VoicePreviewPopup extends StatefulWidget {
  final String audioPath;
  final int duration;
  final FlutterSoundPlayer audioPlayer;
  final bool isPlayerInitialized;
  final Future<void> Function() onInitializePlayer;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _VoicePreviewPopup({
    required this.audioPath,
    required this.duration,
    required this.audioPlayer,
    required this.isPlayerInitialized,
    required this.onInitializePlayer,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<_VoicePreviewPopup> createState() => _VoicePreviewPopupState();
}

class _VoicePreviewPopupState extends State<_VoicePreviewPopup> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  StreamSubscription? _playerSubscription;

  @override
  void dispose() {
    _stopPreview();
    _playerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      } else {
        // Initialize player if needed
        await widget.onInitializePlayer();

        // Set fast subscription for smooth waveform animation
        await widget.audioPlayer.setSubscriptionDuration(
          const Duration(milliseconds: 50),
        );

        // Subscribe to progress BEFORE starting
        _playerSubscription?.cancel();
        _playerSubscription = widget.audioPlayer.onProgress!.listen((e) {
          if (mounted && e.duration.inMilliseconds > 0) {
            setState(() {
              _playbackProgress =
                  e.position.inMilliseconds / e.duration.inMilliseconds;
            });
          }
        });

        setState(() {
          _isPlaying = true;
          _playbackProgress = 0.0;
        });

        await widget.audioPlayer.startPlayer(
          fromURI: widget.audioPath,
          codec: Codec.aacADTS,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error playing preview: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPreview() async {
    try {
      if (_isPlaying) {
        await widget.audioPlayer.stopPlayer();
      }
    } catch (_) {}
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio Player UI - WhatsApp style
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF007AFF), width: 2),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause button
                      GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF5856D6,
                                ).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Waveform / Progress bar
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Waveform visualization with animation
                            SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(20, (index) {
                                  final isActive =
                                      index / 20 <= _playbackProgress;
                                  final heights = [
                                    8.0,
                                    14.0,
                                    10.0,
                                    18.0,
                                    12.0,
                                    20.0,
                                    16.0,
                                    22.0,
                                    14.0,
                                    10.0,
                                    16.0,
                                    20.0,
                                    12.0,
                                    18.0,
                                    14.0,
                                    10.0,
                                    16.0,
                                    20.0,
                                    14.0,
                                    12.0,
                                  ];
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 2.5,
                                    height: heights[index],
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF007AFF)
                                          : Colors.white30,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Duration text
                            Text(
                              _formatTime(widget.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mic icon
                      const Icon(Icons.mic, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onCancel();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Send button
                  GestureDetector(
                    onTap: () async {
                      await _stopPreview();
                      widget.onSend();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF5856D6,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Send',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== FORWARD MESSAGE SCREEN ====================

class _ForwardMessageScreen extends StatefulWidget {
  final String currentUserId;

  const _ForwardMessageScreen({required this.currentUserId});

  @override
  State<_ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<_ForwardMessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final Set<Map<String, dynamic>> _selectedUsers = {};
  String _searchQuery = '';
  List<Map<String, dynamic>> _allContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      // Query conversations
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: widget.currentUserId)
          .limit(50)
          .get();

      // Sort locally by lastMessageTime
      final sortedDocs = conversationsSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime =
              (a.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          final bTime =
              (b.data()['lastMessageTime'] as Timestamp?)?.toDate() ??
              DateTime(2000);
          return bTime.compareTo(aTime);
        });

      final contacts = <Map<String, dynamic>>[];

      for (final doc in sortedDocs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != widget.currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          contacts.add({
            'uid': otherUserId,
            'name': userData['name'] ?? 'Unknown',
            'photoUrl': userData['photoUrl'] ?? userData['profileImageUrl'],
            'email': userData['email'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredContacts {
    final contactsWithoutSelf = _allContacts.where((contact) {
      return contact['uid'] != widget.currentUserId;
    }).toList();

    if (_searchQuery.isEmpty) return contactsWithoutSelf;
    return contactsWithoutSelf.where((contact) {
      final name = (contact['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _toggleSelection(Map<String, dynamic> contact) {
    setState(() {
      final existingUser = _selectedUsers
          .where((u) => u['uid'] == contact['uid'])
          .firstOrNull;
      if (existingUser != null) {
        _selectedUsers.remove(existingUser);
      } else {
        _selectedUsers.add(contact);
      }
    });
  }

  bool _isSelected(String uid) {
    return _selectedUsers.any((u) => u['uid'] == uid);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0f0f23) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF1a1a2e)
            : AppColors.iosBlue,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        ),
        title: const Text(
          'Forward to...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedUsers.toList());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Send (${_selectedUsers.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Selected users chips
          if (_selectedUsers.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = _selectedUsers.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: Colors.green.withValues(alpha: 0.5),
                      ),
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundImage:
                            PhotoUrlHelper.isValidUrl(user['photoUrl'])
                            ? CachedNetworkImageProvider(user['photoUrl']!)
                            : null,
                        child: !PhotoUrlHelper.isValidUrl(user['photoUrl'])
                            ? Text(
                                user['name'][0].toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                      ),
                      label: Text(
                        user['name'].split(' ').first,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 12,
                        ),
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        size: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      onDeleted: () => _toggleSelection(user),
                    ),
                  );
                },
              ),
            ),

          // Contacts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      'No contacts found',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final isSelected = _isSelected(contact['uid']);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              PhotoUrlHelper.isValidUrl(contact['photoUrl'])
                              ? CachedNetworkImageProvider(contact['photoUrl']!)
                              : null,
                          child: !PhotoUrlHelper.isValidUrl(contact['photoUrl'])
                              ? Text(
                                  contact['name'][0].toUpperCase(),
                                  style: const TextStyle(fontSize: 18),
                                )
                              : null,
                        ),
                        title: Text(
                          contact['name'],
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle:
                            contact['email'] != null &&
                                contact['email'].isNotEmpty
                            ? Text(
                                contact['email'],
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(
                                Icons.circle_outlined,
                                color: Colors.grey,
                              ),
                        onTap: () => _toggleSelection(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
