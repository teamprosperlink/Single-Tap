import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to fix data inconsistencies in Firestore
/// Run this ONCE to fix existing data issues
class DataFixService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fix conversations without isGroup field
  /// This fixes the issue where group call messages appear in 1-on-1 chats
  Future<Map<String, dynamic>> fixConversationIsGroupField() async {
    try {
      debugPrint('🔧 DataFixService: Starting conversation isGroup fix...');

      final snapshot = await _firestore.collection('conversations').get();
      final batch = _firestore.batch();
      int fixedCount = 0;
      int totalCount = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final conversationId = doc.id;

        // Check if isGroup field is missing or incorrect
        if (data['isGroup'] == null) {
          // Determine isGroup based on ID format
          // Group IDs start with "group_"
          // 1-on-1 IDs are in format "userId1_userId2"
          final isGroup = conversationId.startsWith('group_');

          debugPrint(
            '  Fixing conversation $conversationId: isGroup = $isGroup',
          );

          batch.update(doc.reference, {'isGroup': isGroup});
          fixedCount++;
        } else {
          // Verify isGroup matches ID format
          final currentIsGroup = data['isGroup'] as bool;
          final expectedIsGroup = conversationId.startsWith('group_');

          if (currentIsGroup != expectedIsGroup) {
            debugPrint(
              '  ⚠️ Mismatch found in $conversationId: isGroup=$currentIsGroup but ID format suggests $expectedIsGroup',
            );
            debugPrint('    Fixing to match ID format...');

            batch.update(doc.reference, {'isGroup': expectedIsGroup});
            fixedCount++;
          }
        }
      }

      if (fixedCount > 0) {
        await batch.commit();
        debugPrint(
          '  DataFixService: Fixed $fixedCount out of $totalCount conversations',
        );
      } else {
        debugPrint(
          '  DataFixService: All $totalCount conversations are correct!',
        );
      }

      return {
        'success': true,
        'totalConversations': totalCount,
        'fixedConversations': fixedCount,
        'message': 'Fixed $fixedCount out of $totalCount conversations',
      };
    } catch (e) {
      debugPrint('  DataFixService: Error fixing conversations: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error fixing conversations: $e',
      };
    }
  }

  /// Verify data integrity and return report
  Future<Map<String, dynamic>> verifyDataIntegrity() async {
    try {
      debugPrint('  DataFixService: Verifying data integrity...');

      final snapshot = await _firestore.collection('conversations').get();

      int missingIsGroupCount = 0;
      int mismatchCount = 0;
      int correctCount = 0;
      final List<String> problematicIds = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final conversationId = doc.id;

        if (data['isGroup'] == null) {
          missingIsGroupCount++;
          problematicIds.add(conversationId);
        } else {
          final currentIsGroup = data['isGroup'] as bool;
          final expectedIsGroup = conversationId.startsWith('group_');

          if (currentIsGroup != expectedIsGroup) {
            mismatchCount++;
            problematicIds.add(conversationId);
          } else {
            correctCount++;
          }
        }
      }

      debugPrint('  Total conversations: ${snapshot.docs.length}');
      debugPrint('  Correct: $correctCount');
      debugPrint('  Missing isGroup: $missingIsGroupCount');
      debugPrint('  Mismatched: $mismatchCount');

      return {
        'totalConversations': snapshot.docs.length,
        'correctCount': correctCount,
        'missingIsGroupCount': missingIsGroupCount,
        'mismatchCount': mismatchCount,
        'problematicIds': problematicIds,
        'needsFix': missingIsGroupCount > 0 || mismatchCount > 0,
      };
    } catch (e) {
      debugPrint('  DataFixService: Error verifying data: $e');
      return {'error': e.toString()};
    }
  }

  /// Get all conversations with call messages for debugging
  Future<void> debugPrintCallMessages() async {
    try {
      debugPrint('🐛 DataFixService: Checking call messages...');

      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .get();

      for (var convDoc in conversationsSnapshot.docs) {
        final conversationId = convDoc.id;
        final isGroup = convDoc.data()['isGroup'] ?? false;

        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('actionType', isEqualTo: 'call')
            .get();

        if (messagesSnapshot.docs.isNotEmpty) {
          debugPrint(
            '  Conversation $conversationId (isGroup=$isGroup) has ${messagesSnapshot.docs.length} call messages',
          );

          for (var msgDoc in messagesSnapshot.docs) {
            final msgData = msgDoc.data();
            debugPrint(
              '    Message: ${msgData['text']}, callId: ${msgData['callId']}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('  DataFixService: Error debugging call messages: $e');
    }
  }

  /// Advanced diagnostic: Find conversations with mismatched data
  Future<Map<String, dynamic>> diagnoseConversations() async {
    try {
      debugPrint('  DataFixService: Running advanced diagnostics...');

      final snapshot = await _firestore.collection('conversations').get();

      final List<Map<String, dynamic>> issues = [];
      int groupConvsWithWrongId = 0;
      int oneOnOneWithGroupMessages = 0;

      for (var doc in snapshot.docs) {
        final conversationId = doc.id;
        final data = doc.data();
        final isGroup = data['isGroup'] ?? false;
        final groupName = data['groupName'];
        final participants = List<String>.from(data['participants'] ?? []);

        // Check 1: isGroup=true but ID doesn't start with "group_"
        if (isGroup && !conversationId.startsWith('group_')) {
          groupConvsWithWrongId++;
          issues.add({
            'conversationId': conversationId,
            'issue': 'Group conversation with non-group ID',
            'isGroup': isGroup,
            'groupName': groupName,
            'participants': participants.length,
          });
          debugPrint(
            '  Issue: $conversationId - isGroup=true but ID is not group format',
          );
        }

        // Check 2: isGroup=false but has groupName or >2 participants
        if (!isGroup && (groupName != null || participants.length > 2)) {
          oneOnOneWithGroupMessages++;
          issues.add({
            'conversationId': conversationId,
            'issue': '1-on-1 conversation with group characteristics',
            'isGroup': isGroup,
            'groupName': groupName,
            'participants': participants.length,
          });
          debugPrint(
            '  Issue: $conversationId - isGroup=false but has groupName or >2 participants',
          );
        }

        // Check 3: Check messages for type mismatch
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .limit(50)
            .get();

        bool hasGroupCreationMessage = false;
        int groupCallMessages = 0;

        for (var msgDoc in messagesSnapshot.docs) {
          final msgData = msgDoc.data();
          final text = msgData['text'] ?? '';

          if (text.contains('Group created by')) {
            hasGroupCreationMessage = true;
          }

          if (msgData['actionType'] == 'call' && text.contains('joined')) {
            groupCallMessages++;
          }
        }

        // Check 4: Has group messages but isGroup=false
        if (!isGroup && (hasGroupCreationMessage || groupCallMessages > 0)) {
          issues.add({
            'conversationId': conversationId,
            'issue': '1-on-1 conversation contains group messages',
            'isGroup': isGroup,
            'hasGroupCreation': hasGroupCreationMessage,
            'groupCallMessages': groupCallMessages,
          });
          debugPrint(
            '  Issue: $conversationId - isGroup=false but has group creation or group call messages',
          );
        }
      }

      debugPrint('\n  Diagnostic Results:');
      debugPrint('  Total conversations: ${snapshot.docs.length}');
      debugPrint('  Group convs with wrong ID: $groupConvsWithWrongId');
      debugPrint(
        '  1-on-1 with group characteristics: $oneOnOneWithGroupMessages',
      );
      debugPrint('  Total issues found: ${issues.length}\n');

      return {
        'totalConversations': snapshot.docs.length,
        'totalIssues': issues.length,
        'issues': issues,
      };
    } catch (e) {
      debugPrint('  DataFixService: Error in diagnostics: $e');
      return {'error': e.toString()};
    }
  }

  /// Delete conversations that have wrong structure
  Future<Map<String, dynamic>> cleanupBrokenConversations() async {
    try {
      debugPrint('  DataFixService: Cleaning up broken conversations...');

      final diagnostics = await diagnoseConversations();
      if (diagnostics['error'] != null) {
        return {'success': false, 'error': diagnostics['error']};
      }

      final issues = List<Map<String, dynamic>>.from(
        diagnostics['issues'] ?? [],
      );
      final batch = _firestore.batch();
      int deletedCount = 0;

      for (var issue in issues) {
        final conversationId = issue['conversationId'] as String;
        final issueType = issue['issue'] as String;

        // Delete conversations that are clearly broken
        if (issueType == 'Group conversation with non-group ID' ||
            issueType == '1-on-1 conversation contains group messages') {
          debugPrint(
            '  Deleting broken conversation: $conversationId ($issueType)',
          );

          // Delete the conversation document
          batch.delete(
            _firestore.collection('conversations').doc(conversationId),
          );
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('  Deleted $deletedCount broken conversations');
      }

      return {
        'success': true,
        'deletedCount': deletedCount,
        'message': 'Deleted $deletedCount broken conversations',
      };
    } catch (e) {
      debugPrint('  DataFixService: Error cleaning up: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
