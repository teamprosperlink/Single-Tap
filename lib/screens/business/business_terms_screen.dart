import 'package:flutter/material.dart';

/// Screen displaying Terms of Service and Privacy Policy
class BusinessTermsScreen extends StatefulWidget {
  const BusinessTermsScreen({super.key});

  @override
  State<BusinessTermsScreen> createState() => _BusinessTermsScreenState();
}

class _BusinessTermsScreenState extends State<BusinessTermsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'Terms & Conditions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00D67D),
          unselectedLabelColor: isDarkMode ? Colors.white54 : Colors.grey[600],
          indicatorColor: const Color(0xFF00D67D),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsOfService(isDarkMode),
          _buildPrivacyPolicy(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildTermsOfService(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last updated: January 1, 2025',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              title: '1. Acceptance of Terms',
              content:
                  'By accessing and using this business platform, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to these terms, please do not use our service.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '2. Business Account',
              content:
                  'To use our business features, you must create a business account. You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '3. Business Conduct',
              content:
                  'As a business user, you agree to:\n• Provide accurate and complete business information\n• Maintain up-to-date contact details\n• Respond to customer inquiries in a timely manner\n• Not engage in fraudulent or deceptive practices\n• Comply with all applicable laws and regulations',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '4. Content Guidelines',
              content:
                  'You are responsible for all content you post. Content must not:\n• Be false, misleading, or deceptive\n• Infringe on intellectual property rights\n• Contain harmful or malicious content\n• Violate any laws or regulations',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '5. Intellectual Property',
              content:
                  'All content and materials available on the platform are protected by intellectual property laws. You retain ownership of content you create but grant us a license to display and distribute it on our platform.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '6. Limitation of Liability',
              content:
                  'We provide the platform "as is" without warranties. We are not liable for any indirect, incidental, or consequential damages arising from your use of the platform.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '7. Termination',
              content:
                  'We reserve the right to terminate or suspend your account at any time for violations of these terms. You may also terminate your account at any time by contacting support.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '8. Changes to Terms',
              content:
                  'We may update these terms from time to time. We will notify you of significant changes. Continued use of the platform after changes constitutes acceptance of the new terms.',
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicy(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last updated
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D67D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Last updated: January 1, 2025',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              title: '1. Information We Collect',
              content:
                  'We collect information you provide directly:\n• Business profile information (name, address, contact details)\n• Product and service listings\n• Customer communications\n• Usage data and analytics',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '2. How We Use Your Information',
              content:
                  'We use your information to:\n• Provide and improve our services\n• Connect you with potential customers\n• Send important notifications\n• Analyze platform usage\n• Prevent fraud and ensure security',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '3. Information Sharing',
              content:
                  'We may share your business information with:\n• Customers viewing your profile\n• Service providers who assist our operations\n• Legal authorities when required by law\n\nWe do not sell your personal information to third parties.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '4. Data Security',
              content:
                  'We implement industry-standard security measures to protect your data. However, no method of transmission over the Internet is 100% secure.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '5. Your Rights',
              content:
                  'You have the right to:\n• Access your personal data\n• Correct inaccurate data\n• Delete your account and data\n• Export your data\n• Opt out of marketing communications',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '6. Cookies and Tracking',
              content:
                  'We use cookies and similar technologies to improve your experience, analyze usage, and personalize content. You can manage cookie preferences in your browser settings.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '7. Data Retention',
              content:
                  'We retain your data for as long as your account is active. After account deletion, we may retain certain information as required by law or for legitimate business purposes.',
              isDarkMode: isDarkMode,
            ),

            _buildSection(
              title: '8. Contact Us',
              content:
                  'If you have questions about this privacy policy or our data practices, please contact us at support@plink.com',
              isDarkMode: isDarkMode,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
