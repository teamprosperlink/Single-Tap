import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/conversation_model.dart';

ConversationModel _makeConversation({
  List<String> participantIds = const ['user-1', 'user-2'],
  Map<String, String>? participantNames,
  Map<String, String?>? participantPhotos,
  Map<String, int>? unreadCount,
  Map<String, bool>? isTyping,
  bool isGroup = false,
  String? groupName,
  String? groupPhoto,
  Map<String, dynamic>? metadata,
}) {
  return ConversationModel(
    id: 'conv-1',
    participantIds: participantIds,
    participantNames: participantNames ?? {'user-1': 'Alice', 'user-2': 'Bob'},
    participantPhotos: participantPhotos ?? {'user-1': 'alice.jpg', 'user-2': 'bob.jpg'},
    unreadCount: unreadCount ?? {},
    isTyping: isTyping ?? {},
    isGroup: isGroup,
    groupName: groupName,
    groupPhoto: groupPhoto,
    createdAt: DateTime(2024, 1, 1),
    lastSeen: {},
    metadata: metadata,
  );
}

void main() {
  group('ConversationModel - getOtherParticipantId', () {
    test('returns the other participant', () {
      final conv = _makeConversation();
      expect(conv.getOtherParticipantId('user-1'), 'user-2');
      expect(conv.getOtherParticipantId('user-2'), 'user-1');
    });

    test('returns empty string when only self in list', () {
      final conv = _makeConversation(participantIds: ['user-1']);
      expect(conv.getOtherParticipantId('user-1'), '');
    });
  });

  group('ConversationModel - getDisplayName', () {
    test('returns other participant name for 1-on-1', () {
      final conv = _makeConversation();
      expect(conv.getDisplayName('user-1'), 'Bob');
      expect(conv.getDisplayName('user-2'), 'Alice');
    });

    test('returns group name for group chat', () {
      final conv = _makeConversation(
        isGroup: true,
        groupName: 'Team Chat',
      );
      expect(conv.getDisplayName('user-1'), 'Team Chat');
    });

    test('returns Group Chat when group has no name', () {
      final conv = _makeConversation(isGroup: true);
      expect(conv.getDisplayName('user-1'), 'Group Chat');
    });

    test('returns Unknown User when participant not in names map', () {
      final conv = _makeConversation(participantNames: {});
      expect(conv.getDisplayName('user-1'), 'Unknown User');
    });
  });

  group('ConversationModel - getDisplayPhoto', () {
    test('returns other participant photo for 1-on-1', () {
      final conv = _makeConversation();
      expect(conv.getDisplayPhoto('user-1'), 'bob.jpg');
    });

    test('returns group photo for group chat', () {
      final conv = _makeConversation(
        isGroup: true,
        groupPhoto: 'group.jpg',
      );
      expect(conv.getDisplayPhoto('user-1'), 'group.jpg');
    });

    test('returns null for group without photo', () {
      final conv = _makeConversation(isGroup: true);
      expect(conv.getDisplayPhoto('user-1'), isNull);
    });
  });

  group('ConversationModel - unread messages', () {
    test('hasUnreadMessages returns true when count > 0', () {
      final conv = _makeConversation(unreadCount: {'user-1': 3});
      expect(conv.hasUnreadMessages('user-1'), isTrue);
    });

    test('hasUnreadMessages returns false when count is 0', () {
      final conv = _makeConversation(unreadCount: {'user-1': 0});
      expect(conv.hasUnreadMessages('user-1'), isFalse);
    });

    test('hasUnreadMessages returns false when user not in map', () {
      final conv = _makeConversation(unreadCount: {});
      expect(conv.hasUnreadMessages('user-1'), isFalse);
    });

    test('getUnreadCount returns correct count', () {
      final conv = _makeConversation(unreadCount: {'user-1': 5});
      expect(conv.getUnreadCount('user-1'), 5);
    });

    test('getUnreadCount returns 0 for missing user', () {
      final conv = _makeConversation(unreadCount: {});
      expect(conv.getUnreadCount('user-1'), 0);
    });
  });

  group('ConversationModel - typing', () {
    test('isUserTyping returns true when typing', () {
      final conv = _makeConversation(isTyping: {'user-2': true});
      expect(conv.isUserTyping('user-2'), isTrue);
    });

    test('isUserTyping returns false when not typing', () {
      final conv = _makeConversation(isTyping: {'user-2': false});
      expect(conv.isUserTyping('user-2'), isFalse);
    });

    test('isUserTyping returns false for missing user', () {
      final conv = _makeConversation(isTyping: {});
      expect(conv.isUserTyping('user-2'), isFalse);
    });
  });

  group('ConversationModel - business chat', () {
    test('isBusinessChat returns true with metadata flag', () {
      final conv = _makeConversation(metadata: {'isBusinessChat': true});
      expect(conv.isBusinessChat, isTrue);
    });

    test('isBusinessChat returns false without metadata', () {
      final conv = _makeConversation();
      expect(conv.isBusinessChat, isFalse);
    });

    test('business getters extract from metadata', () {
      final conv = _makeConversation(metadata: {
        'isBusinessChat': true,
        'businessId': 'biz-1',
        'businessName': 'Test Shop',
        'businessLogo': 'logo.jpg',
        'businessSenderId': 'user-2',
      });
      expect(conv.businessId, 'biz-1');
      expect(conv.businessName, 'Test Shop');
      expect(conv.businessLogo, 'logo.jpg');
      expect(conv.businessSenderId, 'user-2');
    });

    test('getDisplayNameWithBusiness shows business name', () {
      final conv = _makeConversation(metadata: {
        'isBusinessChat': true,
        'businessName': 'Super Store',
        'businessSenderId': 'user-2',
      });
      expect(conv.getDisplayNameWithBusiness('user-1'), 'Super Store');
    });

    test('getDisplayNameWithBusiness shows personal name when not business sender', () {
      final conv = _makeConversation(metadata: {
        'isBusinessChat': true,
        'businessName': 'Super Store',
        'businessSenderId': 'user-1', // current user is the business
      });
      // Looking from user-1's perspective, other participant is user-2 (Bob)
      // user-2 is NOT the businessSenderId, so personal name is shown
      expect(conv.getDisplayNameWithBusiness('user-1'), 'Bob');
    });

    test('getDisplayPhotoWithBusiness shows business logo', () {
      final conv = _makeConversation(metadata: {
        'isBusinessChat': true,
        'businessLogo': 'biz-logo.jpg',
        'businessSenderId': 'user-2',
      });
      expect(conv.getDisplayPhotoWithBusiness('user-1'), 'biz-logo.jpg');
    });

    test('getDisplayPhotoWithBusiness falls back to participant photo', () {
      final conv = _makeConversation(metadata: {
        'isBusinessChat': true,
        'businessSenderId': 'user-2',
        // no businessLogo
      });
      expect(conv.getDisplayPhotoWithBusiness('user-1'), 'bob.jpg');
    });
  });

  group('ConversationModel - copyWith', () {
    test('preserves unchanged fields', () {
      final original = _makeConversation();
      final copy = original.copyWith(lastMessage: 'Hello');
      expect(copy.lastMessage, 'Hello');
      expect(copy.id, 'conv-1');
      expect(copy.participantIds, ['user-1', 'user-2']);
    });
  });
}
