import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ChatService - Handles all chat-related operations
///
/// This service manages:
/// - Chat creation between two users
/// - Checking if a chat already exists
/// - Retrieving existing chats
/// - Preventing duplicate chat creation using transactions
///
/// IMPORTANT: This service uses DETERMINISTIC CHAT IDs to ensure
/// that a chat between two users always has the same ID, preventing duplicates.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // ignore: unused_field

  // ═══════════════════════════════════════════════════════════════
  // 2️⃣ CHAT ID GENERATION FORMULA
  // ═══════════════════════════════════════════════════════════════

  /// Generates a DETERMINISTIC chat ID from two user IDs
  ///
  /// Formula: Sort the UIDs alphabetically, then concatenate with underscore
  ///
  /// Example:
  ///   User A: "abc123"
  ///   User B: "xyz789"
  ///   ChatId: "abc123_xyz789"
  ///
  /// Why this works:
  /// - Always produces the same ID regardless of who initiates the chat
  /// - Prevents duplicate chats between the same two users
  /// - Simple and deterministic
  /// - No need for complex queries to find existing chats
  ///
  /// @param uid1 First user's UID
  /// @param uid2 Second user's UID
  /// @return Deterministic chat ID
  String generateChatId(String uid1, String uid2) {
    // Sort UIDs alphabetically to ensure consistency
    final sortedUids = [uid1, uid2]..sort();

    // Join with underscore
    final chatId = '${sortedUids[0]}_${sortedUids[1]}';
    return chatId;
  }

  // ═══════════════════════════════════════════════════════════════
  // 3️⃣ GET OR CREATE CHAT - MAIN FUNCTION
  // ═══════════════════════════════════════════════════════════════

  /// Gets an existing chat or creates a new one between two users
  ///
  /// This is the MAIN function that handles the entire flow:
  /// 1. Generate deterministic chatId
  /// 2. Check if chat document exists
  /// 3. If exists, return the chatId
  /// 4. If not, create new chat using TRANSACTION (prevents race conditions)
  /// 5. Return the chatId
  ///
  /// TRANSACTION SAFETY:
  /// - Uses Firestore transaction to prevent duplicate creation
  /// - If two users click at the same time, only one chat is created
  /// - Transaction ensures atomicity (all-or-nothing)
  ///
  /// @param myUid Current user's UID
  /// @param otherUid Other user's UID
  /// @param otherUserName Other user's name (for display)
  /// @param otherUserPhoto Other user's photo URL (for display)
  /// @return Future<String> The chat ID
  Future<String> getOrCreateChat(
    String myUid,
    String otherUid, {
    String? otherUserName,
    String? otherUserPhoto,
  }) async {
    try {
      // STEP 1: Generate deterministic chat ID
      final chatId = generateChatId(myUid, otherUid);

      // Use 'conversations' collection to maintain compatibility with existing chat system
      final chatRef = _firestore.collection('conversations').doc(chatId);

      // STEP 2: Check if chat already exists
      final chatSnapshot = await chatRef.get();

      if (chatSnapshot.exists) {
        // Chat already exists - just return the ID
        return chatId;
      }

      // STEP 3: Chat doesn't exist - create it using TRANSACTION
      // Transactions prevent race conditions when both users click simultaneously

      await _firestore.runTransaction((transaction) async {
        // Double-check within transaction (another user might have created it)
        final freshSnapshot = await transaction.get(chatRef);

        if (!freshSnapshot.exists) {
          // Still doesn't exist - safe to create
          final now = FieldValue.serverTimestamp();

          // Get current user's info
          final currentUserDoc = await _firestore
              .collection('users')
              .doc(myUid)
              .get();
          final currentUserData = currentUserDoc.data();

          // Create conversation in format compatible with existing system
          transaction.set(chatRef, {
            'id': chatId,

            // Participants - CRITICAL for security rules and queries
            'participants': [myUid, otherUid],

            // Participant details for quick UI display (matches existing format)
            'participantNames': {
              myUid: currentUserData?['name'] ?? 'Unknown',
              otherUid: otherUserName ?? 'Unknown',
            },

            'participantPhotos': {
              myUid: currentUserData?['photoUrl'],
              otherUid: otherUserPhoto,
            },

            // Last message info (empty initially)
            'lastMessage': null,
            'lastMessageSenderId': null,
            'lastMessageTime': null,

            // Timestamps
            'createdAt': now,

            // Unread counts for each user
            'unreadCount': {myUid: 0, otherUid: 0},

            // Additional fields for compatibility
            'isTyping': {myUid: false, otherUid: false},

            'lastSeen': {myUid: now, otherUid: null},

            // Status flags
            'isGroup': false,
            'isArchived': false,
            'isMuted': false,
          });
        }
      });

      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ADDITIONAL HELPER FUNCTIONS
  // ═══════════════════════════════════════════════════════════════

  /// Gets all chats for the current user
  ///
  /// @param userId Current user's UID
  /// @return Stream of chat documents
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Sends a message in a chat
  ///
  /// @param chatId The chat ID
  /// @param message Message text
  /// @param senderId Sender's UID
  Future<void> sendMessage({
    required String chatId,
    required String message,
    required String senderId,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final chatRef = _firestore.collection('conversations').doc(chatId);
      final messagesRef = chatRef.collection('messages');

      // Add message to subcollection
      await messagesRef.add({
        'senderId': senderId,
        'text': message,
        'timestamp': now,
        'read': false,
        'type': 'text',
      });

      // Update chat metadata
      await chatRef.update({
        'lastMessage': message,
        'lastMessageSenderId': senderId,
        'lastMessageTime': now,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Gets messages for a specific chat
  ///
  /// @param chatId The chat ID
  /// @return Stream of message documents
  Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Marks messages as read
  ///
  /// @param chatId The chat ID
  /// @param userId Current user's UID
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final chatRef = _firestore.collection('conversations').doc(chatId);

      // Update unread count for this user
      await chatRef.update({'unreadCount.$userId': 0});
    } catch (e) {
      // Silently ignore errors
    }
  }

  /// Deletes a chat (for both users)
  ///
  /// @param chatId The chat ID
  Future<void> deleteChat(String chatId) async {
    try {
      final chatRef = _firestore.collection('conversations').doc(chatId);

      // Delete all messages first
      final messagesSnapshot = await chatRef.collection('messages').get();
      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the chat document
      await chatRef.delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Gets the other user's ID in a chat
  ///
  /// @param chatId The chat ID
  /// @param myUid Current user's UID
  /// @return Other user's UID
  String getOtherUserId(String chatId, String myUid) {
    final parts = chatId.split('_');
    return parts[0] == myUid ? parts[1] : parts[0];
  }
}
