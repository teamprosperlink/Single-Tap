import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final Map<String, bool> isTyping;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final DateTime createdAt;
  final Map<String, DateTime?> lastSeen;
  final bool isArchived;
  final bool isMuted;
  final Map<String, dynamic>? metadata;
  UserProfile? otherUser;

  ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    required this.unreadCount,
    required this.isTyping,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    required this.createdAt,
    required this.lastSeen,
    this.isArchived = false,
    this.isMuted = false,
    this.metadata,
    this.otherUser,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both old and new conversation formats
    final participantIds = data.containsKey('participantIds')
        ? List<String>.from(data['participantIds'] ?? [])
        : List<String>.from(data['participants'] ?? []);

    return ConversationModel(
      id: doc.id,
      participantIds: participantIds,
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      participantPhotos: Map<String, String?>.from(
        data['participantPhotos'] ?? {},
      ),
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      isTyping: Map<String, bool>.from(data['isTyping'] ?? {}),
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      groupPhoto: data['groupPhoto'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastSeen:
          (data['lastSeen'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              value != null ? (value as Timestamp).toDate() : null,
            ),
          ) ??
          {},
      isArchived: data['isArchived'] ?? false,
      isMuted: data['isMuted'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participantIds,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'isTyping': isTyping,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhoto': groupPhoto,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen.map(
        (key, value) =>
            MapEntry(key, value != null ? Timestamp.fromDate(value) : null),
      ),
      'isArchived': isArchived,
      'isMuted': isMuted,
      'metadata': metadata,
    };
  }

  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  String getDisplayName(String currentUserId) {
    if (isGroup) {
      return groupName ?? 'Group Chat';
    } else {
      final otherUserId = getOtherParticipantId(currentUserId);
      return participantNames[otherUserId] ?? 'Unknown User';
    }
  }

  String? getDisplayPhoto(String currentUserId) {
    if (isGroup) {
      return groupPhoto;
    } else {
      final otherUserId = getOtherParticipantId(currentUserId);
      return participantPhotos[otherUserId];
    }
  }

  bool hasUnreadMessages(String userId) {
    return (unreadCount[userId] ?? 0) > 0;
  }

  int getUnreadCount(String userId) {
    return unreadCount[userId] ?? 0;
  }

  bool isUserTyping(String userId) {
    return isTyping[userId] ?? false;
  }

  // Business chat helper getters
  bool get isBusinessChat => metadata?['isBusinessChat'] == true;

  String? get businessId => metadata?['businessId'] as String?;

  String? get businessName => metadata?['businessName'] as String?;

  String? get businessLogo => metadata?['businessLogo'] as String?;

  String? get businessSenderId => metadata?['businessSenderId'] as String?;

  // Get display name with business indicator
  String getDisplayNameWithBusiness(String currentUserId) {
    if (isGroup) {
      return groupName ?? 'Group Chat';
    }

    final otherUserId = getOtherParticipantId(currentUserId);
    final name = participantNames[otherUserId] ?? 'Unknown User';

    // If the other participant is a business, show business name
    if (isBusinessChat && businessSenderId == otherUserId) {
      return businessName ?? name;
    }

    return name;
  }

  // Get photo with business logo fallback
  String? getDisplayPhotoWithBusiness(String currentUserId) {
    if (isGroup) {
      return groupPhoto;
    }

    final otherUserId = getOtherParticipantId(currentUserId);

    // If the other participant is a business, show business logo
    if (isBusinessChat && businessSenderId == otherUserId && businessLogo != null) {
      return businessLogo;
    }

    return participantPhotos[otherUserId];
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    Map<String, String?>? participantPhotos,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    Map<String, bool>? isTyping,
    bool? isGroup,
    String? groupName,
    String? groupPhoto,
    DateTime? createdAt,
    Map<String, DateTime?>? lastSeen,
    bool? isArchived,
    bool? isMuted,
    Map<String, dynamic>? metadata,
    UserProfile? otherUser,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      participantPhotos: participantPhotos ?? this.participantPhotos,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isTyping: isTyping ?? this.isTyping,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupPhoto: groupPhoto ?? this.groupPhoto,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      metadata: metadata ?? this.metadata,
      otherUser: otherUser ?? this.otherUser,
    );
  }
}
