import 'package:flutter/material.dart';
import '../../../services/location_services/gemini_service.dart';

/// AI-powered description generation button
/// Uses Gemini to generate product descriptions
class AIDescriptionButton extends StatefulWidget {
  final String listingTitle;
  final String category;
  final Function(String) onDescriptionGenerated;

  const AIDescriptionButton({
    super.key,
    required this.listingTitle,
    required this.category,
    required this.onDescriptionGenerated,
  });

  @override
  State<AIDescriptionButton> createState() => _AIDescriptionButtonState();
}

class _AIDescriptionButtonState extends State<AIDescriptionButton> {
  bool _isGenerating = false;
  final GeminiService _geminiService = GeminiService();

  Future<void> _generateDescription() async {
    if (widget.listingTitle.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final prompt = '''
Generate a compelling product description for: ${widget.listingTitle}
Category: ${widget.category}

Requirements:
- 2-3 short paragraphs
- Professional and engaging tone
- Highlight key features and benefits
- Use persuasive language
- Include relevant keywords for SEO
- Keep it concise (100-150 words)

Only return the description text, no additional commentary or formatting.
''';

      final description = await _geminiService.generateContent(prompt);

      if (description != null && description.isNotEmpty) {
        widget.onDescriptionGenerated(description.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Description generated successfully!'),
              backgroundColor: Color(0xFF7C3AED),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('No description generated');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating description: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isGenerating ? null : _generateDescription,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        side: const BorderSide(color: Color(0xFF7C3AED)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: _isGenerating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              ),
            )
          : const Icon(
              Icons.auto_awesome,
              size: 18,
              color: Color(0xFF7C3AED),
            ),
      label: Text(
        _isGenerating ? 'Generating...' : 'AI Generate',
        style: const TextStyle(
          color: Color(0xFF7C3AED),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
