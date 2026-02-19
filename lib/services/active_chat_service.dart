/// Service to track which chat screen is currently active
/// Used to prevent notifications for messages in the open chat (SingleTap-style)
class ActiveChatService {
  static final ActiveChatService _instance = ActiveChatService._internal();
  factory ActiveChatService() => _instance;
  ActiveChatService._internal();

  /// Currently active conversation ID (null if no chat is open)
  String? _activeConversationId;

  /// Currently active user ID being chatted with (null if no chat is open)
  String? _activeUserId;

  /// Set the active chat when user opens a conversation
  void setActiveChat({String? conversationId, String? userId}) {
    _activeConversationId = conversationId;
    _activeUserId = userId;
    print(
      '[ActiveChat] Active chat set: conversationId=$conversationId, userId=$userId',
    );
  }

  /// Clear active chat when user closes the conversation
  void clearActiveChat() {
    print(
      '[ActiveChat] Clearing active chat: was conversationId=$_activeConversationId, userId=$_activeUserId',
    );
    _activeConversationId = null;
    _activeUserId = null;
  }

  /// Check if a conversation is currently active/open
  bool isConversationActive(String? conversationId) {
    if (conversationId == null || _activeConversationId == null) {
      return false;
    }
    return _activeConversationId == conversationId;
  }

  /// Check if a chat with a specific user is currently active/open
  bool isUserChatActive(String? userId) {
    if (userId == null || _activeUserId == null) {
      return false;
    }
    return _activeUserId == userId;
  }

  /// Get current active conversation ID
  String? get activeConversationId => _activeConversationId;

  /// Get current active user ID
  String? get activeUserId => _activeUserId;
}
