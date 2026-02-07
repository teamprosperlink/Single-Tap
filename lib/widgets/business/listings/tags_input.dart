import 'package:flutter/material.dart';

/// Shared tags input component for listing wizards
/// Supports up to 5 tags with AI-powered suggestions
class TagsInput extends StatefulWidget {
  final List<String> tags;
  final Function(List<String>) onTagsChanged;
  final int maxTags;
  final List<String>? suggestedTags; // AI-generated suggestions

  const TagsInput({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.maxTags = 5,
    this.suggestedTags,
  });

  @override
  State<TagsInput> createState() => _TagsInputState();
}

class _TagsInputState extends State<TagsInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isEmpty) return;
    if (widget.tags.length >= widget.maxTags) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${widget.maxTags} tags allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (widget.tags.contains(trimmedTag)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tag already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final updatedTags = List<String>.from(widget.tags);
    updatedTags.add(trimmedTag);
    widget.onTagsChanged(updatedTags);
    _controller.clear();
  }

  void _removeTag(String tag) {
    final updatedTags = List<String>.from(widget.tags);
    updatedTags.remove(tag);
    widget.onTagsChanged(updatedTags);
  }

  void _addSuggestedTag(String tag) {
    _addTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final availableSuggestions = widget.suggestedTags
        ?.where((tag) => !widget.tags.contains(tag))
        .toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '${widget.tags.length}/${widget.maxTags}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Add tags to help customers find your listing',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),

        // Current tags
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                labelStyle: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w500,
                ),
                deleteIconColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                ),
              );
            }).toList(),
          ),

        if (widget.tags.isNotEmpty) const SizedBox(height: 12),

        // Tag input field
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.tags.length < widget.maxTags,
                textInputAction: TextInputAction.done,
                onSubmitted: _addTag,
                decoration: InputDecoration(
                  hintText: 'Add a tag...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: widget.tags.length < widget.maxTags
                  ? () => _addTag(_controller.text)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        // AI Suggestions
        if (availableSuggestions.isNotEmpty && widget.tags.length < widget.maxTags) ...[
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 6),
              Text(
                'Suggested Tags',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSuggestions.map((tag) {
              return ActionChip(
                label: Text(tag),
                avatar: const Icon(Icons.add, size: 16),
                onPressed: () => _addSuggestedTag(tag),
                backgroundColor: Colors.white,
                labelStyle: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
