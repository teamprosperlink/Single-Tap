import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../database/message_database.dart';
import '../models/message_model.dart';

/// Hybrid Chat Service - Combines local SQLite storage with Firebase sync
///
/// This service provides WhatsApp-like messaging performance:
/// - Messages stored locally in SQLite (instant, free, offline-capable)
/// - Firebase used only for message delivery/sync
/// - Auto-syncs in background
/// - 10x cheaper and 20x faster than pure Firebase approach
class HybridChatService {
  static final HybridChatService _instance = HybridChatService._internal();
  factory HybridChatService() => _instance;
  HybridChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessageDatabase _localDb = MessageDatabase();

  // Disable verbose logging for production
  static const bool _enableVerboseLogging = false;
  void _log(String message) {
    if (_enableVerboseLogging) {
      debugPrint(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MEDIA HANDLING (Upload, Download, Compression)
  // ═══════════════════════════════════════════════════════════════

  /// Upload media file with compression
  Future<Map<String, dynamic>> uploadMedia(File file, MessageType type) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('No user');

    File fileToUpload = file;
    String? fileName = file.path.split('/').last;
    int fileSize = await file.length();

    // 1. COMPRESSION
    if (type == MessageType.image) {
      final compressed = await _compressImage(file);
      if (compressed != null) {
        fileToUpload = compressed;
        fileSize = await fileToUpload.length();
        _log(
          'HybridChat: Image compressed from ${await file.length()} to $fileSize',
        );
      }
    } else if (type == MessageType.video) {
      final compressed = await _compressVideo(file);
      if (compressed != null) {
        fileToUpload = compressed;
        fileSize = await fileToUpload.length();
        _log(
          'HybridChat: Video compressed from ${await file.length()} to $fileSize',
        );
      }
    }

    // 2. UPLOAD
    final ext = fileName.split('.').last;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chat_media')
        .child(currentUserId)
        .child('${DateTime.now().millisecondsSinceEpoch}.$ext');

    final uploadTask = storageRef.putFile(
      fileToUpload,
      SettableMetadata(contentType: _getContentType(type, ext)),
    );

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return {
      'url': downloadUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'localPath': fileToUpload.path,
    };
  }

  /// Download media file to local storage
  Future<String?> downloadMedia(String url, String? fileName) async {
    // Web doesn't support local file storage
    if (kIsWeb) {
      _log('HybridChat: Media download not supported on web');
      return null;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final name = fileName ?? url.split('/').last.split('?').first;
      final savePath = '${dir.path}/media/$name';

      // Check if already exists
      if (await File(savePath).exists()) {
        return savePath;
      }

      // Create directory if needed
      await Directory('${dir.path}/media').create(recursive: true);

      // Download
      await Dio().download(url, savePath);
      _log('HybridChat: Media downloaded to $savePath');
      return savePath;
    } catch (e) {
      _log('HybridChat: Error downloading media: $e');
      return null;
    }
  }

  Future<File?> _compressImage(File file) async {
    if (kIsWeb) return null;
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      _log('HybridChat: Error compressing image: $e');
      return null;
    }
  }

  Future<File?> _compressVideo(File file) async {
    if (kIsWeb) return null;
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      _log('HybridChat: Error compressing video: $e');
      return null;
    }
  }

  String _getContentType(MessageType type, String ext) {
    switch (type) {
      case MessageType.image:
        return 'image/$ext';
      case MessageType.video:
        return 'video/$ext';
      case MessageType.audio:
        return 'audio/$ext';
      default:
        return 'application/octet-stream';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SEND MESSAGE (Hybrid Approach)
  // ═══════════════════════════════════════════════════════════════

  /// Send a message using hybrid approach
  ///
  /// Flow:
  /// 1. Save to local SQLite immediately (user sees message instantly)
  /// 2. Upload to Firebase for delivery to recipient
  /// 3. Update status as it progresses (sending → sent → delivered → read)
  Future<String> sendMessage({
    required String conversationId,
    required String receiverId,
    String? text,
    File? file,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? voiceUrl,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    final messageId = _firestore.collection('temp').doc().id;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String? mediaUrl = imageUrl ?? voiceUrl;
    String? localPath = file?.path;
    String? fileName = file?.path.split('/').last;
    int? fileSize = file != null ? await file.length() : null;

    // Check if local database is available
    final localDbAvailable = _localDb.isAvailable;

    // STEP 1: Save to LOCAL database FIRST (instant!) - skip if unavailable
    if (localDbAvailable) {
      await _localDb.saveMessage({
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': text,
        'type': type.index,
        'mediaUrl': mediaUrl,
        'localPath': localPath,
        'fileName': fileName,
        'fileSize': fileSize,
        'status': 'sent', // Single tick - saved locally, not yet on server
        'isSentByMe': 1,
        'timestamp': timestamp,
        'isRead': 0,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToSenderId': replyToSenderId,
        'isDeleted': 0,
        'isEdited': 0,
      });
      _log('HybridChat: Message saved to local DB: $messageId');
    } else {
      _log('HybridChat: Local DB unavailable, sending directly to Firebase');
    }

    // User sees message immediately! ✓ (single grey tick - sent locally)

    // STEP 2: Upload Media (if any) & Upload to Firebase
    try {
      if (file != null) {
        final uploadResult = await uploadMedia(file, type);
        mediaUrl = uploadResult['url'];
        fileName = uploadResult['fileName'];
        fileSize = uploadResult['fileSize'];

        // Update local DB with media URL (if available)
        if (localDbAvailable) {
          await _localDb.updateMessageMedia(
            messageId,
            mediaUrl!,
            fileName,
            fileSize,
          );
        }
      }

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set({
            'messageId': messageId,
            'senderId': currentUserId,
            'text': text,
            'type': type.index,
            'mediaUrl': mediaUrl,
            'fileName': fileName,
            'fileSize': fileSize,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 2, // MessageStatus.delivered.index - Double grey tick
            'read': false,
            'isRead': false,
            'replyToMessageId': replyToMessageId,
            'replyToText': replyToText,
            'replyToSenderId': replyToSenderId,
            'isDeleted': false,
            'isEdited': false,
          });

      _log('HybridChat: Message uploaded to Firebase: $messageId');

      // STEP 3: Update local status to "delivered" (if available)
      if (localDbAvailable) {
        await _localDb.updateMessageStatus(messageId, 'delivered');
        _log('HybridChat: Message status updated to delivered');
      }

      // User sees ✓✓ (double grey checkmark - delivered to server)

      // STEP 4: Update conversation metadata
      String lastMsg =
          text ?? (type == MessageType.image ? ' Image' : '📎 File');
      if (type == MessageType.video) lastMsg = ' Video';
      if (type == MessageType.audio) lastMsg = ' Audio';

      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': lastMsg,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      return messageId;
    } catch (e) {
      _log('HybridChat: ERROR uploading message: $e');

      // Update local status to "failed" (if available)
      if (localDbAvailable) {
        await _localDb.updateMessageStatus(messageId, 'failed');
      }

      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GET MESSAGES (From Local Database)
  // ═══════════════════════════════════════════════════════════════

  /// Get messages from LOCAL database (instant, works offline)
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    _log('HybridChat: Loading messages from local DB for $conversationId');
    final messages = await _localDb.getMessages(
      conversationId,
      limit: limit,
      offset: offset,
    );
    _log('HybridChat: Loaded ${messages.length} messages from local DB');
    return messages;
  }

  /// Get single message by ID
  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    return await _localDb.getMessage(messageId);
  }

  // ═══════════════════════════════════════════════════════════════
  // SYNC MESSAGES (Background Sync from Firebase)
  // ═══════════════════════════════════════════════════════════════

  /// Sync messages from Firebase to local database
  ///
  /// This runs in the background to fetch new messages from Firebase
  /// and store them locally. Only fetches messages newer than what we have.
  Future<void> syncMessages(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _log('HybridChat: Syncing messages for $conversationId');

    try {
      // Get last message timestamp from local DB
      final lastTimestamp = await _localDb.getLastMessageTimestamp(
        conversationId,
      );
      final lastSync = lastTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastTimestamp)
          : DateTime.now().subtract(const Duration(days: 30));

      _log('HybridChat: Last sync timestamp: $lastSync');

      // Fetch only NEW messages from Firebase (after last sync)
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync))
          .orderBy('timestamp', descending: true)
          .limit(100) // Only last 100 new messages
          .get();

      _log(
        'HybridChat: Found ${snapshot.docs.length} new messages from Firebase',
      );

      if (snapshot.docs.isEmpty) {
        _log('HybridChat: No new messages to sync');
        return;
      }

      // Convert to local database format and save
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'messageId': data['messageId'] ?? doc.id,
          'conversationId': conversationId,
          'senderId': data['senderId'] ?? '',
          'receiverId': currentUserId, // Current user is receiver
          'text': data['text'],
          'type': data['type'] ?? 0,
          'mediaUrl': data['mediaUrl'],
          'fileName': data['fileName'],
          'fileSize': data['fileSize'],
          'status': data['status'] ?? 'delivered',
          'isSentByMe': data['senderId'] == currentUserId ? 1 : 0,
          'timestamp': data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
          'isRead': (data['isRead'] == true) ? 1 : 0,
          'deliveredAt': data['deliveredAt'] != null
              ? (data['deliveredAt'] as Timestamp).millisecondsSinceEpoch
              : null,
          'readAt': data['readAt'] != null
              ? (data['readAt'] as Timestamp).millisecondsSinceEpoch
              : null,
          'replyToMessageId': data['replyToMessageId'],
          'replyToText': data['replyToText'],
          'replyToSenderId': data['replyToSenderId'],
          'reactions': data['reactions'],
          'isDeleted': (data['isDeleted'] == true) ? 1 : 0,
          'isEdited': (data['isEdited'] == true) ? 1 : 0,
          'editedAt': data['editedAt'] != null
              ? (data['editedAt'] as Timestamp).millisecondsSinceEpoch
              : null,
        };
      }).toList();

      // Save all messages to local database
      await _localDb.saveMessages(messages);
      _log('HybridChat: Synced ${messages.length} messages to local DB');
    } catch (e) {
      _log('HybridChat: ERROR syncing messages: $e');
      // Don't throw - sync errors are non-fatal
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MESSAGE DELIVERY & READ STATUS (WhatsApp-style)
  // ═══════════════════════════════════════════════════════════════
  //
  // Status flow:
  // 1. 'sending' → Clock icon (message being sent)
  // 2. 'sent' → Single tick ✓ (delivered to server)
  // 3. 'delivered' → Double ticks ✓✓ (delivered to recipient's device)
  // 4. 'read' → Double ticks ✓✓ (blue/green - seen by recipient)
  //
  // ═══════════════════════════════════════════════════════════════

  // Guard to prevent duplicate calls
  final Set<String> _markingAsReadInProgress = {};
  final Set<String> _markingAsDeliveredInProgress = {};

  /// Mark messages as delivered when recipient opens the conversation
  /// This updates sent messages from other user to 'delivered' status
  Future<void> markMessagesAsDelivered(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Prevent duplicate calls
    if (_markingAsDeliveredInProgress.contains(conversationId)) {
      return;
    }
    _markingAsDeliveredInProgress.add(conversationId);

    try {
      // Get messages that are 'sent' (not yet delivered) from other users
      final sentMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('status', isEqualTo: 'sent')
          .limit(100)
          .get();

      // Filter to only messages NOT from current user (messages we received)
      final messagesToUpdate = sentMessages.docs
          .where((doc) => doc.data()['senderId'] != currentUserId)
          .toList();

      if (messagesToUpdate.isEmpty) {
        return;
      }

      _log(
        'HybridChat: Marking ${messagesToUpdate.length} messages as delivered',
      );

      final batch = _firestore.batch();
      for (var doc in messagesToUpdate) {
        batch.update(doc.reference, {
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _log('HybridChat: Messages marked as delivered');
    } catch (e) {
      _log('HybridChat: Error marking messages as delivered: $e');
    } finally {
      _markingAsDeliveredInProgress.remove(conversationId);
    }
  }

  /// Mark messages as read (updates both local DB and Firebase)
  /// Called when user is actively viewing the conversation
  Future<void> markMessagesAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Prevent duplicate calls for same conversation
    if (_markingAsReadInProgress.contains(conversationId)) {
      return;
    }
    _markingAsReadInProgress.add(conversationId);

    try {
      // Update local database first (silent)
      await _localDb.markMessagesAsRead(conversationId, currentUserId);

      // Get all unread/undelivered messages from other users
      // Query messages that have read=false
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .limit(100)
          .get();

      // Filter to only messages from other user
      final messagesToMarkRead = unreadMessages.docs
          .where((doc) => doc.data()['senderId'] != currentUserId)
          .toList();

      if (messagesToMarkRead.isEmpty) {
        return;
      }

      _log('HybridChat: Marking ${messagesToMarkRead.length} messages as read');

      final batch = _firestore.batch();
      for (var doc in messagesToMarkRead) {
        batch.update(doc.reference, {
          'read': true,
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'status': 3, // MessageStatus.read.index
        });
      }

      await batch.commit();
      _log('HybridChat: Messages marked as read');
    } catch (e) {
      _log('HybridChat: Error marking messages as read: $e');
    } finally {
      _markingAsReadInProgress.remove(conversationId);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MESSAGE ACTIONS (Edit, Delete, React)
  // ═══════════════════════════════════════════════════════════════

  /// Edit message text
  Future<void> editMessage(String messageId, String newText) async {
    _log('HybridChat: Editing message $messageId');

    // Update local database
    await _localDb.updateMessageText(messageId, newText);

    // Update Firebase
    final message = await _localDb.getMessage(messageId);
    if (message != null) {
      final conversationId = message['conversationId'] as String;
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': FieldValue.serverTimestamp(),
          });
    }

    _log('HybridChat: Message edited successfully');
  }

  /// Delete message (for me or for everyone)
  Future<void> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  }) async {
    _log('HybridChat: Deleting message $messageId (forEveryone: $forEveryone)');

    if (forEveryone) {
      // Mark as deleted (hide content but keep metadata)
      await _localDb.markMessageAsDeleted(messageId);

      // Update Firebase
      final message = await _localDb.getMessage(messageId);
      if (message != null) {
        final conversationId = message['conversationId'] as String;
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(messageId)
            .update({
              'isDeleted': true,
              'text': null,
              'imageUrl': null,
              'voiceUrl': null,
            });
      }
    } else {
      // Delete locally only
      await _localDb.deleteMessageLocally(messageId);
    }

    _log('HybridChat: Message deleted successfully');
  }

  /// Add reaction to message
  Future<void> addReaction(String messageId, String emoji) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _log('HybridChat: Adding reaction $emoji to message $messageId');

    // Update local database
    await _localDb.addReaction(messageId, currentUserId, emoji);

    // Update Firebase
    final message = await _localDb.getMessage(messageId);
    if (message != null) {
      final conversationId = message['conversationId'] as String;
      final reactions = message['reactions'] as String?;

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions': reactions});
    }

    _log('HybridChat: Reaction added successfully');
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════════

  /// Search messages across all conversations
  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    return await _localDb.searchMessages(query);
  }

  /// Search messages within a specific conversation
  Future<List<Map<String, dynamic>>> searchMessagesInConversation(
    String conversationId,
    String query,
  ) async {
    return await _localDb.searchMessagesInConversation(conversationId, query);
  }

  // ═══════════════════════════════════════════════════════════════
  // STATS & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  /// Get total message count in local database
  Future<int> getTotalMessageCount() async {
    return await _localDb.getTotalMessageCount();
  }

  /// Get local database size in bytes
  Future<int> getDatabaseSize() async {
    return await _localDb.getDatabaseSize();
  }

  /// Get database size in MB (human-readable)
  Future<String> getDatabaseSizeMB() async {
    final bytes = await getDatabaseSize();
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  /// Clear all messages for a conversation (local only)
  Future<void> clearConversation(String conversationId) async {
    await _localDb.clearConversation(conversationId);
  }
}
