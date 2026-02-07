import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/conversation_model.dart';
import '../../models/user_profile.dart';
import '../../models/business_model.dart';

class ConversationService {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Validate and fix conversation participants array if corrupted
  /// Returns true if the conversation was fixed, false if it was already valid
  Future<bool> _validateAndFixParticipants(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!doc.exists) {
        // debugPrint('ConversationService: VALIDATION - Conversation does not exist: $conversationId');
        return false;
      }

      final data = doc.data()!;
      final participants = data['participants'] as List<dynamic>?;

      // Extract expected user IDs from conversation ID
      final expectedUserIds = conversationId.split('_');
      if (expectedUserIds.length != 2) {
        // debugPrint('ConversationService: VALIDATION - Invalid conversation ID format: $conversationId');
        return false;
      }

      // Check if participants array needs fixing
      bool needsFix = false;

      if (participants == null || participants.isEmpty) {
        // debugPrint('ConversationService: VALIDATION - Participants array is null or empty');
        needsFix = true;
      } else if (participants.length != 2) {
        // debugPrint('ConversationService: VALIDATION - Participants array has wrong length: ${participants.length}');
        needsFix = true;
      } else {
        // Check if both expected users are in the array
        final participantsList = participants.cast<String>();
        for (final userId in expectedUserIds) {
          if (!participantsList.contains(userId)) {
            // debugPrint('ConversationService: VALIDATION - Missing user $userId in participants array');
            needsFix = true;
            break;
          }
        }
      }

      if (needsFix) {
        // debugPrint('ConversationService: VALIDATION - Fixing participants array for $conversationId');
        await doc.reference.update({'participants': expectedUserIds});
        // debugPrint('ConversationService: VALIDATION - Fixed! Updated to: $expectedUserIds');
        return true;
      }

      return false;
    } catch (e) {
      // debugPrint('ConversationService: VALIDATION ERROR for $conversationId: $e');
      return false;
    }
  }

  // Generate consistent conversation ID between two users
  String generateConversationId(String userId1, String userId2) {
    // Always sort user IDs to ensure consistency
    final sortedIds = [userId1, userId2]..sort();
    final conversationId = '${sortedIds[0]}_${sortedIds[1]}';
    return conversationId;
  }

  // Get or create conversation between current user and another user
  Future<String> getOrCreateConversation(UserProfile otherUser) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      // debugPrint('ConversationService: ERROR - No authenticated user');
      throw Exception('No authenticated user');
    }

    // Generate consistent conversation ID
    final conversationId = generateConversationId(currentUserId, otherUser.uid);
    // debugPrint('ConversationService: Getting or creating conversation: $conversationId');
    // debugPrint('ConversationService: Current user: $currentUserId, Other user: ${otherUser.uid}');

    try {
      // First, try to get existing conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        // Return immediately for faster loading
        // Run validation in background (non-blocking)
        Future.microtask(() async {
          await _validateAndFixParticipants(conversationId);
          await _updateParticipantInfo(conversationId, currentUserId, otherUser);
        });
        return conversationId;
      }

      // debugPrint('ConversationService: Conversation does not exist, creating new one: $conversationId');
      // Conversation doesn't exist, create it
      await _createConversation(conversationId, currentUserId, otherUser);
      // debugPrint('ConversationService: Conversation created successfully: $conversationId');
      return conversationId;
    } catch (e) {
      // debugPrint('ConversationService: ERROR creating/getting conversation: $e');
      rethrow;
    }
  }

  // Create a new conversation
  Future<void> _createConversation(
    String conversationId,
    String currentUserId,
    UserProfile otherUser,
  ) async {
    // debugPrint('ConversationService: Creating conversation document...');

    // VALIDATION: Ensure user IDs are valid and different
    if (currentUserId.isEmpty || otherUser.uid.isEmpty) {
      throw Exception(
        'Invalid user IDs: currentUserId=$currentUserId, otherUserId=${otherUser.uid}',
      );
    }

    if (currentUserId == otherUser.uid) {
      throw Exception(
        'Cannot create conversation with self: userId=$currentUserId',
      );
    }

    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();

    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserName =
        currentUserData['name'] ?? _auth.currentUser?.displayName ?? 'User';
    final currentUserPhoto =
        currentUserData['photoUrl'] ?? _auth.currentUser?.photoURL;

    // debugPrint('ConversationService: Current user name: $currentUserName');
    // debugPrint('ConversationService: Other user name: ${otherUser.name}');
    // debugPrint('ConversationService: Participants: [$currentUserId, ${otherUser.uid}]');

    // CRITICAL: Create participants array with both user IDs
    final participantsArray = [currentUserId, otherUser.uid];

    // VALIDATION: Ensure participants array has exactly 2 unique user IDs
    assert(
      participantsArray.length == 2,
      'Participants array must have exactly 2 users',
    );
    assert(
      participantsArray[0] != participantsArray[1],
      'Participants must be different users',
    );

    final conversationData = {
      'id': conversationId,
      'participants': participantsArray,
      'participantNames': {
        currentUserId: currentUserName,
        otherUser.uid: otherUser.name,
      },
      'participantPhotos': {
        currentUserId: currentUserPhoto,
        otherUser.uid: otherUser.profileImageUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': null,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'unreadCount': {currentUserId: 0, otherUser.uid: 0},
      'isTyping': {currentUserId: false, otherUser.uid: false},
      'isGroup': false,
      'lastSeen': {
        currentUserId: FieldValue.serverTimestamp(),
        otherUser.uid: null,
      },
      'isArchived': false,
      'isMuted': false,
    };

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData);
      // debugPrint('ConversationService: Conversation document created successfully');
    } catch (e) {
      // debugPrint('ConversationService: ERROR creating conversation document: $e');
      rethrow;
    }
  }

  // Update participant information in existing conversation
  Future<void> _updateParticipantInfo(
    String conversationId,
    String currentUserId,
    UserProfile otherUser,
  ) async {
    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .get();

    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserName =
        currentUserData['name'] ?? _auth.currentUser?.displayName ?? 'User';
    final currentUserPhoto =
        currentUserData['photoUrl'] ?? _auth.currentUser?.photoURL;

    // IMPORTANT: Validate participants array before updating other info
    // This is a safety check in case the array was corrupted
    await _validateAndFixParticipants(conversationId);

    // Update participant info to ensure it's current
    await _firestore.collection('conversations').doc(conversationId).update({
      'participantNames.$currentUserId': currentUserName,
      'participantNames.${otherUser.uid}': otherUser.name,
      'participantPhotos.$currentUserId': currentUserPhoto,
      'participantPhotos.${otherUser.uid}': otherUser.profileImageUrl,
      'lastSeen.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  // Check if conversation exists between two users
  Future<bool> conversationExists(String userId1, String userId2) async {
    final conversationId = generateConversationId(userId1, userId2);
    final doc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    return doc.exists;
  }

  // Get conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (doc.exists) {
        return ConversationModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Error getting conversation
      return null;
    }
  }

  // Create or get conversation with user IDs (overloaded method)
  Future<String> createOrGetConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    // Generate consistent conversation ID
    final conversationId = generateConversationId(currentUserId, otherUserId);

    try {
      // First, try to get existing conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        return conversationId;
      }

      // Get other user's profile
      final otherUserDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      if (!otherUserDoc.exists) {
        throw Exception('Other user not found');
      }

      // Use fromFirestore to get proper name (with phone fallback)
      final otherUser = UserProfile.fromFirestore(otherUserDoc);

      // Create conversation
      await _createConversation(conversationId, currentUserId, otherUser);
      return conversationId;
    } catch (e) {
      rethrow;
    }
  }

  // Send a message to a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? imageUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    try {
      // Create message document
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'text': text,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'isEdited': false,
          });

      // Update conversation with last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      // Update unread count for other participants
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        final participantIds = List<String>.from(
          conversationDoc.data()!['participants'],
        );
        final otherUserIds = participantIds.where((id) => id != currentUserId);

        final updates = <String, dynamic>{};
        for (final userId in otherUserIds) {
          updates['unreadCount.$userId'] = FieldValue.increment(1);
        }

        if (updates.isNotEmpty) {
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .update(updates);
        }
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get all conversations for current user
  Stream<List<ConversationModel>> getUserConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .limit(50) // Only load last 50 conversations
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConversationModel.fromFirestore(doc))
              .toList();
        });
  }

  // Delete duplicate conversations (cleanup utility)
  Future<void> cleanupDuplicateConversations() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Group conversations by participants
      final Map<String, List<QueryDocumentSnapshot>> groupedConversations = {};

      for (var doc in conversations.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        participants.sort();
        final key = participants.join('_');

        if (!groupedConversations.containsKey(key)) {
          groupedConversations[key] = [];
        }
        groupedConversations[key]!.add(doc);
      }

      // Find and merge duplicates
      for (var entry in groupedConversations.entries) {
        if (entry.value.length > 1) {
          // Sort by last message time, keep the most recent
          entry.value.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // Keep the first (most recent) and delete others
          for (int i = 1; i < entry.value.length; i++) {
            await _mergeAndDeleteConversation(
              entry.value[0].id, // Keep this one
              entry.value[i].id, // Delete this one
            );
          }
        }
      }
    } catch (e) {
      // Error cleaning up duplicate conversations
    }
  }

  // Merge messages from duplicate conversation and delete it
  Future<void> _mergeAndDeleteConversation(
    String keepConversationId,
    String deleteConversationId,
  ) async {
    try {
      // Get all messages from the conversation to be deleted
      final messagesToMove = await _firestore
          .collection('conversations')
          .doc(deleteConversationId)
          .collection('messages')
          .get();

      // Move messages to the conversation we're keeping
      final batch = _firestore.batch();

      for (var messageDoc in messagesToMove.docs) {
        final newMessageRef = _firestore
            .collection('conversations')
            .doc(keepConversationId)
            .collection('messages')
            .doc(messageDoc.id);

        batch.set(newMessageRef, messageDoc.data());
      }

      // Delete the duplicate conversation
      batch.delete(
        _firestore.collection('conversations').doc(deleteConversationId),
      );

      await batch.commit();

      // Merged and deleted duplicate conversation
    } catch (e) {
      // Error merging conversation
    }
  }

  // Update last seen timestamp
  Future<void> updateLastSeen(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastSeen.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  /// Delete orphaned conversations where one or more participants no longer exist
  /// Returns the number of conversations deleted
  Future<int> deleteOrphanedConversations() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      // debugPrint('ConversationService: No authenticated user for cleanup');
      return 0;
    }

    int deletedCount = 0;

    try {
      // debugPrint('ConversationService: Starting orphaned conversations cleanup...');

      // Get all conversations for current user
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      // debugPrint('ConversationService: Found ${conversationsSnapshot.docs.length} conversations to check');

      for (var conversationDoc in conversationsSnapshot.docs) {
        try {
          final data = conversationDoc.data();
          final participants = List<String>.from(data['participants'] ?? []);

          // Check if all participants exist in users collection
          bool hasOrphanedUser = false;

          for (var userId in participants) {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();

            if (!userDoc.exists) {
              // debugPrint('ConversationService: Found orphaned user: $userId in conversation ${conversationDoc.id}');
              hasOrphanedUser = true;
              break;
            }
          }

          // Delete conversation if it has orphaned users
          if (hasOrphanedUser) {
            // debugPrint('ConversationService: Deleting orphaned conversation: ${conversationDoc.id}');

            // Delete all messages in the conversation first
            final messagesSnapshot = await _firestore
                .collection('conversations')
                .doc(conversationDoc.id)
                .collection('messages')
                .get();

            final batch = _firestore.batch();
            for (var messageDoc in messagesSnapshot.docs) {
              batch.delete(messageDoc.reference);
            }

            // Delete the conversation document
            batch.delete(conversationDoc.reference);

            await batch.commit();
            deletedCount++;
            // debugPrint('ConversationService: Successfully deleted orphaned conversation: ${conversationDoc.id}');
          }
        } catch (e) {
          // debugPrint('ConversationService: Error processing conversation ${conversationDoc.id}: $e');
        }
      }

      // debugPrint('ConversationService: Cleanup complete. Deleted $deletedCount orphaned conversations');
      return deletedCount;
    } catch (e) {
      // debugPrint('ConversationService: Error during orphaned conversations cleanup: $e');
      return deletedCount;
    }
  }

  /// Check if a specific conversation is orphaned (has non-existent users)
  Future<bool> isConversationOrphaned(String conversationId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        return true; // Consider non-existent conversations as orphaned
      }

      final data = conversationDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);

      // Check if all participants exist
      for (var userId in participants) {
        final userDoc = await _firestore.collection('users').doc(userId).get();

        if (!userDoc.exists) {
          return true; // Found an orphaned user
        }
      }

      return false; // All participants exist
    } catch (e) {
      // debugPrint('ConversationService: Error checking if conversation is orphaned: $e');
      return false;
    }
  }

  // ============= BUSINESS CONVERSATION METHODS =============

  /// Generate a business conversation ID
  /// Format: business_{businessId}_{userId} for consistent lookup
  String generateBusinessConversationId(String businessId, String userId) {
    // Always put business first for consistency
    return 'business_${businessId}_$userId';
  }

  /// Get or create a conversation between a business and a user
  /// The business owner initiates the chat as the business identity
  Future<String> getOrCreateBusinessConversation({
    required BusinessModel business,
    required UserProfile otherUser,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    // Verify current user owns this business
    if (business.userId != currentUserId) {
      throw Exception('User does not own this business');
    }

    // Generate business conversation ID
    final conversationId = generateBusinessConversationId(business.id, otherUser.uid);

    try {
      // Check if conversation exists
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        // Update business info in case it changed
        Future.microtask(() async {
          await _updateBusinessConversationInfo(conversationId, business, otherUser);
        });
        return conversationId;
      }

      // Create new business conversation
      await _createBusinessConversation(conversationId, business, otherUser);
      return conversationId;
    } catch (e) {
      rethrow;
    }
  }

  /// Create a new business conversation
  Future<void> _createBusinessConversation(
    String conversationId,
    BusinessModel business,
    UserProfile otherUser,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    // Participants: business owner (using business identity) and the other user
    final participantsArray = [currentUserId, otherUser.uid];

    final conversationData = {
      'id': conversationId,
      'participants': participantsArray,
      'participantNames': {
        currentUserId: business.businessName, // Show business name instead of owner name
        otherUser.uid: otherUser.name,
      },
      'participantPhotos': {
        currentUserId: business.logo, // Show business logo instead of owner photo
        otherUser.uid: otherUser.profileImageUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': null,
      'lastMessage': null,
      'lastMessageSenderId': null,
      'unreadCount': {currentUserId: 0, otherUser.uid: 0},
      'isTyping': {currentUserId: false, otherUser.uid: false},
      'isGroup': false,
      'lastSeen': {
        currentUserId: FieldValue.serverTimestamp(),
        otherUser.uid: null,
      },
      'isArchived': false,
      'isMuted': false,
      // Business-specific metadata
      'metadata': {
        'isBusinessChat': true,
        'businessId': business.id,
        'businessName': business.businessName,
        'businessLogo': business.logo,
        'businessSenderId': currentUserId,
        'businessOwnerId': business.userId,
      },
    };

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .set(conversationData);
  }

  /// Update business conversation info
  Future<void> _updateBusinessConversationInfo(
    String conversationId,
    BusinessModel business,
    UserProfile otherUser,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'participantNames.$currentUserId': business.businessName,
      'participantNames.${otherUser.uid}': otherUser.name,
      'participantPhotos.$currentUserId': business.logo,
      'participantPhotos.${otherUser.uid}': otherUser.profileImageUrl,
      'metadata.businessName': business.businessName,
      'metadata.businessLogo': business.logo,
      'lastSeen.$currentUserId': FieldValue.serverTimestamp(),
    });
  }

  /// Send a message from business account
  Future<void> sendBusinessMessage({
    required String conversationId,
    required String text,
    required BusinessModel business,
    String? imageUrl,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('No authenticated user');
    }

    // Verify current user owns this business
    if (business.userId != currentUserId) {
      throw Exception('User does not own this business');
    }

    try {
      // Create message with business sender info
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'text': text,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'isEdited': false,
            // Business message metadata
            'isBusinessMessage': true,
            'businessId': business.id,
            'businessName': business.businessName,
          });

      // Update conversation with last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      // Update unread count for other participants
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        final participantIds = List<String>.from(
          conversationDoc.data()!['participants'],
        );
        final otherUserIds = participantIds.where((id) => id != currentUserId);

        final updates = <String, dynamic>{};
        for (final userId in otherUserIds) {
          updates['unreadCount.$userId'] = FieldValue.increment(1);
        }

        if (updates.isNotEmpty) {
          await _firestore
              .collection('conversations')
              .doc(conversationId)
              .update(updates);
        }
      }
    } catch (e) {
      throw Exception('Failed to send business message: $e');
    }
  }

  /// Get all conversations for a specific business
  Stream<List<ConversationModel>> getBusinessConversations(String businessId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // Query conversations where metadata.businessId matches
    return _firestore
        .collection('conversations')
        .where('metadata.businessId', isEqualTo: businessId)
        .orderBy('lastMessageTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConversationModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get business conversation with a specific user
  Future<ConversationModel?> getBusinessConversationWithUser({
    required String businessId,
    required String userId,
  }) async {
    final conversationId = generateBusinessConversationId(businessId, userId);
    return getConversation(conversationId);
  }

  /// Check if a business conversation exists with a user
  Future<bool> businessConversationExists(String businessId, String userId) async {
    final conversationId = generateBusinessConversationId(businessId, userId);
    final doc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    return doc.exists;
  }
}
