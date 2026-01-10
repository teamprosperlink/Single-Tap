import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: November 18, 2025',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Information We Collect',
              'We collect information you provide directly to us, including:\n• Name and email address\n• Profile photo\n• Location data (city/area, not exact GPS)\n• Posts and messages you create\n• Device information and usage data',
            ),
            _buildSection(
              '2. How We Use Your Information',
              'We use the information we collect to:\n• Provide and improve our services\n• Match you with relevant users\n• Send notifications about matches and messages\n• Analyze usage patterns to improve user experience\n• Communicate with you about the service',
            ),
            _buildSection(
              '3. Information Sharing',
              'We do not sell your personal information. We may share your information:\n• With other users (as part of matches and profiles)\n• With service providers who help us operate the app\n• When required by law\n• To protect our rights and safety',
            ),
            _buildSection(
              '4. Location Data',
              'We collect and use location data to:\n• Show your city/area to other users\n• Match you with nearby users\n• Calculate distance to matches\n\nWe do NOT share your exact GPS coordinates. Only your city/area is visible to other users.',
            ),
            _buildSection(
              '5. Data Security',
              'We implement security measures to protect your information, including:\n• Encrypted data transmission\n• Secure authentication\n• Regular security audits\n• Access controls\n\nHowever, no method of transmission over the Internet is 100% secure.',
            ),
            _buildSection(
              '6. Your Rights',
              'You have the right to:\n• Access your personal information\n• Correct inaccurate information\n• Delete your account and data\n• Opt out of notifications\n• Export your data',
            ),
            _buildSection(
              '7. Data Retention',
              'We retain your information:\n• While your account is active\n• For 30 days after account deletion (backup period)\n• Longer if required by law\n\nPosts expire after 30 days and are automatically deleted.',
            ),
            _buildSection(
              '8. Children\'s Privacy',
              'Our service is not intended for users under 18 years of age. We do not knowingly collect information from children.',
            ),
            _buildSection(
              '9. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place.',
            ),
            _buildSection(
              '10. Cookies and Tracking',
              'We use cookies and similar technologies to:\n• Remember your preferences\n• Analyze usage patterns\n• Improve user experience\n\nYou can control cookies through your browser settings.',
            ),
            _buildSection(
              '11. Third-Party Services',
              'We use third-party services including:\n• Firebase (Google) for authentication and database\n• Gemini AI for intent analysis\n• Cloud storage for photos\n\nThese services have their own privacy policies.',
            ),
            _buildSection(
              '12. Changes to Privacy Policy',
              'We may update this policy from time to time. We will notify you of significant changes through the app.',
            ),
            _buildSection(
              '13. GDPR Compliance (EU Users)',
              'If you are in the EU, you have additional rights under GDPR, including:\n• Right to data portability\n• Right to be forgotten\n• Right to restrict processing\n• Right to object to processing',
            ),
            _buildSection(
              '14. CCPA Compliance (California Users)',
              'California residents have rights under CCPA, including:\n• Right to know what data is collected\n• Right to delete personal information\n• Right to opt-out of data sales (we don\'t sell data)',
            ),
            _buildSection(
              '15. Contact Us',
              'If you have questions about this Privacy Policy, please contact us through the app settings.',
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
