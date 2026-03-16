import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common widgets/app_background.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
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
              top: kToolbarHeight + 44, left: 16, right: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: November 18, 2025',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '1. Information We Collect',
                'We collect information you provide directly to us, including:\n\u2022 Name and email address\n\u2022 Profile photo\n\u2022 Location data (city/area, not exact GPS)\n\u2022 Posts and messages you create\n\u2022 Device information and usage data',
              ),
              _buildSection(
                '2. How We Use Your Information',
                'We use the information we collect to:\n\u2022 Provide and improve our services\n\u2022 Match you with relevant users\n\u2022 Send notifications about matches and messages\n\u2022 Analyze usage patterns to improve user experience\n\u2022 Communicate with you about the service',
              ),
              _buildSection(
                '3. Information Sharing',
                'We do not sell your personal information. We may share your information:\n\u2022 With other users (as part of matches and profiles)\n\u2022 With service providers who help us operate the app\n\u2022 When required by law\n\u2022 To protect our rights and safety',
              ),
              _buildSection(
                '4. Location Data',
                'We collect and use location data to:\n\u2022 Show your city/area to other users\n\u2022 Match you with nearby users\n\u2022 Calculate distance to matches\n\nWe do NOT share your exact GPS coordinates. Only your city/area is visible to other users.',
              ),
              _buildSection(
                '5. Data Security',
                'We implement security measures to protect your information, including:\n\u2022 Encrypted data transmission\n\u2022 Secure authentication\n\u2022 Regular security audits\n\u2022 Access controls\n\nHowever, no method of transmission over the Internet is 100% secure.',
              ),
              _buildSection(
                '6. Your Rights',
                'You have the right to:\n\u2022 Access your personal information\n\u2022 Correct inaccurate information\n\u2022 Delete your account and data\n\u2022 Opt out of notifications\n\u2022 Export your data',
              ),
              _buildSection(
                '7. Data Retention',
                'We retain your information:\n\u2022 While your account is active\n\u2022 For 30 days after account deletion (backup period)\n\u2022 Longer if required by law\n\nPosts expire after 30 days and are automatically deleted.',
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
                'We use cookies and similar technologies to:\n\u2022 Remember your preferences\n\u2022 Analyze usage patterns\n\u2022 Improve user experience\n\nYou can control cookies through your browser settings.',
              ),
              _buildSection(
                '11. Third-Party Services',
                'We use third-party services including:\n\u2022 Firebase (Google) for authentication and database\n\u2022 Gemini AI for intent analysis\n\u2022 Cloud storage for photos\n\nThese services have their own privacy policies.',
              ),
              _buildSection(
                '12. Changes to Privacy Policy',
                'We may update this policy from time to time. We will notify you of significant changes through the app.',
              ),
              _buildSection(
                '13. GDPR Compliance (EU Users)',
                'If you are in the EU, you have additional rights under GDPR, including:\n\u2022 Right to data portability\n\u2022 Right to be forgotten\n\u2022 Right to restrict processing\n\u2022 Right to object to processing',
              ),
              _buildSection(
                '14. CCPA Compliance (California Users)',
                'California residents have rights under CCPA, including:\n\u2022 Right to know what data is collected\n\u2022 Right to delete personal information\n\u2022 Right to opt-out of data sales (we don\'t sell data)',
              ),
              _buildSection(
                '15. Contact Us',
                'If you have questions about this Privacy Policy, please contact us through the app settings.',
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
              fontFamily: 'Poppins',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Poppins',
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
