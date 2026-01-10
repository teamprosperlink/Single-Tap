import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Shared chat utilities and widgets for consistent UI across 1-on-1 and group chats

/// Format names to Title Case (e.g., "JOHN DOE" -> "John Doe")
String formatDisplayName(String name) {
  if (name.isEmpty) return name;
  return name.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Chat theme colors for message bubbles
const Map<String, List<Color>> chatThemeColors = {
  'default': [Color(0xFF007AFF), Color(0xFF5856D6)], // iOS Blue-Purple
  'sunset': [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Red-Orange
  'ocean': [Color(0xFF00B4DB), Color(0xFF0083B0)], // Cyan-Blue
  'forest': [Color(0xFF56AB2F), Color(0xFFA8E063)], // Green gradient
  'berry': [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
  'midnight': [Color(0xFF232526), Color(0xFF414345)], // Dark gray
  'rose': [Color(0xFFFF0844), Color(0xFFFFB199)], // Pink-Peach
  'golden': [Color(0xFFF7971E), Color(0xFFFFD200)], // Orange-Gold
};

/// Shared message input widget for both 1-on-1 and group chats
class ChatMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showEmojiPicker;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onEmojiToggle;
  final VoidCallback? onMicTap;
  final Function(String) onChanged;
  final VoidCallback onTextFieldTap;

  const ChatMessageInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.showEmojiPicker,
    required this.isSending,
    required this.onSend,
    required this.onAttachment,
    required this.onEmojiToggle,
    this.onMicTap,
    required this.onChanged,
    required this.onTextFieldTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: showEmojiPicker ? 10 : MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
        border: Border(
          top: BorderSide(
            color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button - Paperclip icon
            GestureDetector(
              onTap: onAttachment,
              child: Container(
                height: 40,
                width: 40,
                margin: const EdgeInsets.only(bottom: 4),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 26,
                ),
              ),
            ),
            // Message input field - Rounded design
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF38383A)
                        : const Color(0xFFE5E5EA),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: false,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                          fontSize: 16,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: onChanged,
                        onTap: onTextFieldTap,
                      ),
                    ),
                    // Emoji button inside text field
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: GestureDetector(
                        onTap: onEmojiToggle,
                        child: Icon(
                          showEmojiPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mic button (when no text)
            if (!hasText && onMicTap != null)
              GestureDetector(
                onTap: onMicTap,
                child: Container(
                  height: 40,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.mic_rounded,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 26,
                  ),
                ),
              ),
            // Send button - Blue circular
            GestureDetector(
              onTap: hasText ? onSend : null,
              child: Container(
                height: 42,
                width: 42,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared emoji picker widget
class ChatEmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback onBackspace;

  const ChatEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final emojiPickerHeight = (screenHeight * 0.35).clamp(200.0, 350.0);

    return Container(
      height: emojiPickerHeight,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
        border: Border(
          top: BorderSide(
            color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) => onEmojiSelected(emoji.emoji),
        onBackspacePressed: onBackspace,
        config: Config(
          height: emojiPickerHeight,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: 8,
            emojiSizeMax: 28 * (kIsWeb ? 1.0 : 1.0),
            verticalSpacing: 0,
            horizontalSpacing: 0,
            gridPadding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
            noRecents: const Text(
              'No Recents',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            indicatorColor: Theme.of(context).primaryColor,
            iconColor: Colors.grey,
            iconColorSelected: Theme.of(context).primaryColor,
            backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF6F6F6),
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          skinToneConfig: const SkinToneConfig(
            enabled: true,
            dialogBackgroundColor: Colors.white,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            buttonIconColor: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Build a consistent message bubble for both chat types
class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime? timestamp;
  final bool isRead;
  final String? senderName; // Only shown in group chats
  final Widget? imageWidget;
  final Widget? replyWidget;
  final List<Color>? themeColors;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.timestamp,
    this.isRead = false,
    this.senderName,
    this.imageWidget,
    this.replyWidget,
    this.themeColors,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = themeColors ?? chatThemeColors['default']!;

    return GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 12,
            right: isMe ? 12 : 60,
            top: 2,
            bottom: 2,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender name (group chat only)
              if (senderName != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    formatDisplayName(senderName!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              // Message bubble
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe
                      ? null
                      : (isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply preview
                      if (replyWidget != null) replyWidget!,
                      // Image
                      if (imageWidget != null) imageWidget!,
                      // Text message
                      if (message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : (isDarkMode ? Colors.white : Colors.black87),
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                        ),
                      // Timestamp and read status
                      if (timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 14,
                            bottom: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(timestamp!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : (isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isRead ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: isRead
                                      ? const Color(0xFF34C759)
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
