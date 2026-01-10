import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen for help and support
class BusinessSupportScreen extends StatefulWidget {
  const BusinessSupportScreen({super.key});

  @override
  State<BusinessSupportScreen> createState() => _BusinessSupportScreenState();
}

class _BusinessSupportScreenState extends State<BusinessSupportScreen> {
  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I add products or services?',
      answer:
          'Go to the Services tab from the bottom navigation. Tap the "+" button to add a new product or service. Fill in the details including name, description, price, and upload images.',
    ),
    FAQItem(
      question: 'How do inquiries work?',
      answer:
          'When customers are interested in your products or services, they can send you an inquiry. You\'ll receive a notification and can view all inquiries in the Inquiries section. From there, you can contact them via call, WhatsApp, or message.',
    ),
    FAQItem(
      question: 'How do I update my business hours?',
      answer:
          'Go to Profile > Business Hours. You can set different hours for each day of the week, mark days as closed, or use quick actions like "Weekdays Only" or "24/7".',
    ),
    FAQItem(
      question: 'How do I go offline temporarily?',
      answer:
          'On your Home dashboard, you\'ll see an Online/Offline toggle at the top. Simply switch it off to hide your business from customers. Switch it back on when you\'re ready to receive inquiries again.',
    ),
    FAQItem(
      question: 'How do I respond to customer reviews?',
      answer:
          'Go to your Business Dashboard and select the Reviews tab. Find the review you want to respond to and tap "Reply". Your response will be visible to all users viewing the review.',
    ),
    FAQItem(
      question: 'How do I edit my business information?',
      answer:
          'Go to Profile and tap the Edit icon in the header. You can update your business name, description, contact information, address, and other details.',
    ),
    FAQItem(
      question: 'Can I have multiple business locations?',
      answer:
          'Currently, each business profile supports one primary location. If you have multiple locations, you can create separate business profiles for each one.',
    ),
    FAQItem(
      question: 'How do I delete my business profile?',
      answer:
          'Go to Profile > scroll to the bottom > tap "Delete Business" in the Danger Zone section. This action is permanent and cannot be undone.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00D67D),
                    const Color(0xFF00D67D).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our support team is here to help you with any questions or issues.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactButton(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          onTap: () => _launchEmail('support@plink.com'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildContactButton(
                          icon: Icons.chat_outlined,
                          label: 'WhatsApp',
                          onTap: () => _launchWhatsApp('+911234567890'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FAQ Section
            _buildSectionTitle('Frequently Asked Questions', isDarkMode),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _faqs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDarkMode ? Colors.white12 : Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  return _FAQTile(
                    faq: _faqs[index],
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Report a Problem
            _buildSectionTitle('Report a Problem', isDarkMode),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.bug_report_outlined,
                    title: 'Report a Bug',
                    subtitle: 'Help us fix technical issues',
                    isDarkMode: isDarkMode,
                    onTap: () => _showReportDialog('Bug Report'),
                  ),
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white12 : Colors.grey[200],
                  ),
                  _buildActionTile(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Share your suggestions with us',
                    isDarkMode: isDarkMode,
                    onTap: () => _showReportDialog('Feedback'),
                  ),
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white12 : Colors.grey[200],
                  ),
                  _buildActionTile(
                    icon: Icons.flag_outlined,
                    title: 'Report Abuse',
                    subtitle: 'Report inappropriate content or behavior',
                    isDarkMode: isDarkMode,
                    onTap: () => _showReportDialog('Abuse Report'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Links
            _buildSectionTitle('Quick Links', isDarkMode),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.article_outlined,
                    title: 'Documentation',
                    isDarkMode: isDarkMode,
                    onTap: () => _launchUrl('https://plink.com/docs'),
                  ),
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white12 : Colors.grey[200],
                  ),
                  _buildLinkTile(
                    icon: Icons.play_circle_outline,
                    title: 'Video Tutorials',
                    isDarkMode: isDarkMode,
                    onTap: () => _launchUrl('https://plink.com/tutorials'),
                  ),
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.white12 : Colors.grey[200],
                  ),
                  _buildLinkTile(
                    icon: Icons.forum_outlined,
                    title: 'Community Forum',
                    isDarkMode: isDarkMode,
                    onTap: () => _launchUrl('https://plink.com/community'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white70 : Colors.grey[700],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF00D67D), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.blue, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 18,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showReportDialog(String type) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: Text(type),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your issue...',
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Color(0xFF00D67D),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D67D),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;
  bool isExpanded;

  FAQItem({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });
}

class _FAQTile extends StatefulWidget {
  final FAQItem faq;
  final bool isDarkMode;

  const _FAQTile({
    required this.faq,
    required this.isDarkMode,
  });

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      iconColor: const Color(0xFF00D67D),
      collapsedIconColor: widget.isDarkMode ? Colors.white54 : Colors.grey[600],
      title: Text(
        widget.faq.question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: widget.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      children: [
        Text(
          widget.faq.answer,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: widget.isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
