import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io';

/// Local SQLite database for storing chat messages
///
/// This database stores ALL messages locally on the device (free, fast, offline)
/// Messages are synced with Firebase for delivery, but kept permanently in local storage
class MessageDatabase {
  static final MessageDatabase _instance = MessageDatabase._internal();
  factory MessageDatabase() => _instance;
  MessageDatabase._internal();

  static Database? _database;
  static bool _initFailed = false;
  static String? _initError;

  /// Check if local database is available
  bool get isAvailable => !kIsWeb && !_initFailed;

  /// Get the initialization error message if any
  String? get initError => _initError;

  Future<Database?> get database async {
    // Web doesn't support sqflite
    if (kIsWeb) {
      _initFailed = true;
      _initError = 'SQLite not supported on web';
      return null;
    }

    if (_initFailed) return null;
    if (_database != null) return _database!;

    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      _initFailed = true;
      _initError = e.toString();
      debugPrint('MessageDatabase: Failed to initialize: $e');
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'messages.db');

    return await openDatabase(
      path,
      version: 2, // Incremented version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        messageId TEXT NOT NULL UNIQUE,
        conversationId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        text TEXT,
        imageUrl TEXT,
        voiceUrl TEXT,
        mediaUrl TEXT,
        localPath TEXT,
        fileName TEXT,
        fileSize INTEGER,
        type INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        isSentByMe INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        deliveredAt INTEGER,
        readAt INTEGER,
        replyToMessageId TEXT,
        replyToText TEXT,
        replyToSenderId TEXT,
        reactions TEXT,
        isDeleted INTEGER DEFAULT 0,
        isEdited INTEGER DEFAULT 0,
        editedAt INTEGER
      )
    ''');

    // Create indexes for faster queries
    await db.execute(
      'CREATE INDEX idx_conversation ON messages(conversationId, timestamp DESC)',
    );
    await db.execute('CREATE INDEX idx_message_id ON messages(messageId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for file sharing
      await db.execute('ALTER TABLE messages ADD COLUMN mediaUrl TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN localPath TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN fileName TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN fileSize INTEGER');
      await db.execute(
        'ALTER TABLE messages ADD COLUMN type INTEGER DEFAULT 0',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // QUERY OPERATIONS (Read from local SQLite)
  // ═══════════════════════════════════════════════════════════════

  /// Get messages for a conversation (with pagination)
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'messages',
      where: 'conversationId = ? AND isDeleted = 0',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get single message by ID
  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query(
      'messages',
      where: 'messageId = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get last message timestamp for a conversation
  Future<int?> getLastMessageTimestamp(String conversationId) async {
    final db = await database;
    if (db == null) return null;
    final results = await db.query(
      'messages',
      columns: ['timestamp'],
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first['timestamp'] as int : null;
  }

  /// Count unread messages in a conversation
  Future<int> countUnreadMessages(
    String conversationId,
    String myUserId,
  ) async {
    final db = await database;
    if (db == null) return 0;
    final results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversationId = ? AND isRead = 0 AND senderId != ?',
      [conversationId, myUserId],
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // WRITE OPERATIONS (Save to local SQLite)
  // ═══════════════════════════════════════════════════════════════

  /// Save a new message to local storage
  /// Returns -1 if database is unavailable
  Future<int> saveMessage(Map<String, dynamic> message) async {
    final db = await database;
    if (db == null) return -1;
    return await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace, // Update if exists
    );
  }

  /// Save multiple messages in batch (for sync)
  Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    final db = await database;
    if (db == null) return;
    final batch = db.batch();
    for (var message in messages) {
      batch.insert(
        'messages',
        message,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update message status (sent → delivered → read)
  Future<int> updateMessageStatus(
    String messageId,
    String status, {
    int? deliveredAt,
    int? readAt,
  }) async {
    final db = await database;
    if (db == null) return 0;
    final updates = <String, dynamic>{'status': status};
    if (deliveredAt != null) updates['deliveredAt'] = deliveredAt;
    if (readAt != null) updates['readAt'] = readAt;

    return await db.update(
      'messages',
      updates,
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Update message media details (after upload)
  Future<int> updateMessageMedia(
    String messageId,
    String mediaUrl,
    String? fileName,
    int? fileSize,
  ) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {'mediaUrl': mediaUrl, 'fileName': fileName, 'fileSize': fileSize},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Mark messages as read
  Future<int> markMessagesAsRead(String conversationId, String myUserId) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {'isRead': 1, 'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'conversationId = ? AND senderId != ? AND isRead = 0',
      whereArgs: [conversationId, myUserId],
    );
  }

  /// Update message text (for edit)
  Future<int> updateMessageText(String messageId, String newText) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {
        'text': newText,
        'isEdited': 1,
        'editedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Delete message locally
  Future<int> deleteMessageLocally(String messageId) async {
    final db = await database;
    if (db == null) return 0;
    return await db.delete(
      'messages',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Mark message as deleted (for "delete for everyone")
  Future<int> markMessageAsDeleted(String messageId) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {'isDeleted': 1, 'text': null, 'imageUrl': null, 'voiceUrl': null},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Add reaction to message
  Future<int> addReaction(String messageId, String userId, String emoji) async {
    final message = await getMessage(messageId);
    if (message == null) return 0;

    // Parse existing reactions (simple format: "userId1:emoji1,userId2:emoji2")
    final reactions = message['reactions'] as String?;
    final reactionMap = <String, String>{};

    if (reactions != null && reactions.isNotEmpty) {
      for (final reaction in reactions.split(',')) {
        final parts = reaction.split(':');
        if (parts.length == 2) {
          reactionMap[parts[0]] = parts[1];
        }
      }
    }

    // Add or update reaction
    reactionMap[userId] = emoji;

    // Convert back to string
    final newReactions = reactionMap.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');

    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {'reactions': newReactions},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Remove reaction from message
  Future<int> removeReaction(String messageId, String userId) async {
    final message = await getMessage(messageId);
    if (message == null) return 0;

    final reactions = message['reactions'] as String?;
    final reactionMap = <String, String>{};

    if (reactions != null && reactions.isNotEmpty) {
      for (final reaction in reactions.split(',')) {
        final parts = reaction.split(':');
        if (parts.length == 2) {
          reactionMap[parts[0]] = parts[1];
        }
      }
    }

    // Remove reaction
    reactionMap.remove(userId);

    // Convert back to string
    final newReactions = reactionMap.isNotEmpty
        ? reactionMap.entries.map((e) => '${e.key}:${e.value}').join(',')
        : null;

    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'messages',
      {'reactions': newReactions},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Search messages across all conversations
  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'messages',
      where: 'text LIKE ? AND isDeleted = 0',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
      limit: 100,
    );
  }

  /// Search messages within a conversation
  Future<List<Map<String, dynamic>>> searchMessagesInConversation(
    String conversationId,
    String query,
  ) async {
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'messages',
      where: 'conversationId = ? AND text LIKE ? AND isDeleted = 0',
      whereArgs: [conversationId, '%$query%'],
      orderBy: 'timestamp DESC',
      limit: 100,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Delete old messages (optional - for storage management)
  Future<int> deleteOldMessages(Duration age) async {
    final db = await database;
    if (db == null) return 0;
    final cutoffTimestamp = DateTime.now().subtract(age).millisecondsSinceEpoch;
    return await db.delete(
      'messages',
      where: 'timestamp < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  /// Clear all messages for a conversation
  Future<int> clearConversation(String conversationId) async {
    final db = await database;
    if (db == null) return 0;
    return await db.delete(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
  }

  /// Get database size in bytes (for storage stats)
  Future<int> getDatabaseSize() async {
    if (kIsWeb) return 0;
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'messages.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('MessageDatabase: Failed to get database size: $e');
    }
    return 0;
  }

  /// Get total message count
  Future<int> getTotalMessageCount() async {
    final db = await database;
    if (db == null) return 0;
    final results = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    return Sqflite.firstIntValue(results) ?? 0;
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    if (db == null) return;
    await db.close();
  }
}
