import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common widgets/app_background.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Terms of Service',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(64, 64, 64, 1),
              ],
            ),
            border: Border(
                bottom: BorderSide(color: Colors.white, width: 0.5)),
          ),
        ),
      ),
      body: AppBackground(
        showParticles: false,
        overlayOpacity: 0.7,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: kToolbarHeight + 44,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: November 18, 2025',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Acceptance of Terms',
                'By accessing and using Single Tap, you accept and agree to be bound by the terms and provision of this agreement.',
              ),
              _buildSection(
                '2. Use License',
                'Permission is granted to temporarily use Single Tap for personal, non-commercial purposes only.',
              ),
              _buildSection(
                '3. User Conduct',
                'You agree to use Single Tap only for lawful purposes and in a way that does not infringe the rights of, restrict or inhibit anyone else\'s use and enjoyment of the service.',
              ),
              _buildSection(
                '4. User Content',
                'You retain all rights to any content you submit, post or display on or through Single Tap. By submitting content, you grant us a worldwide, non-exclusive license to use, modify, and display that content.',
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
                'Single Tap is provided "as is" without any warranties, expressed or implied. We do not warrant that the service will be uninterrupted or error-free.',
              ),
              _buildSection(
                '8. Limitation of Liability',
                'In no event shall Single Tap be liable for any damages arising out of the use or inability to use the service.',
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
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
