import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: November 18, 2025',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using Supper, you accept and agree to be bound by the terms and provision of this agreement.',
            ),
            _buildSection(
              '2. Use License',
              'Permission is granted to temporarily use Supper for personal, non-commercial purposes only.',
            ),
            _buildSection(
              '3. User Conduct',
              'You agree to use Supper only for lawful purposes and in a way that does not infringe the rights of, restrict or inhibit anyone else\'s use and enjoyment of the service.',
            ),
            _buildSection(
              '4. User Content',
              'You retain all rights to any content you submit, post or display on or through Supper. By submitting content, you grant us a worldwide, non-exclusive license to use, modify, and display that content.',
            ),
            _buildSection(
              '5. Prohibited Activities',
              'You may not:\n• Use the service for any illegal purpose\n• Post false, inaccurate, misleading, or defamatory content\n• Harass, abuse, or harm other users\n• Attempt to gain unauthorized access to the service\n• Interfere with or disrupt the service',
            ),
            _buildSection(
              '6. Account Termination',
              'We reserve the right to terminate or suspend your account at our discretion, without notice, for conduct that we believe violates these Terms of Service.',
            ),
            _buildSection(
              '7. Disclaimer',
              'Supper is provided "as is" without any warranties, expressed or implied. We do not warrant that the service will be uninterrupted or error-free.',
            ),
            _buildSection(
              '8. Limitation of Liability',
              'In no event shall Supper be liable for any damages arising out of the use or inability to use the service.',
            ),
            _buildSection(
              '9. Changes to Terms',
              'We reserve the right to modify these terms at any time. We will notify users of any material changes.',
            ),
            _buildSection(
              '10. Contact Us',
              'If you have any questions about these Terms, please contact us through the app.',
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
