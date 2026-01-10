import 'dart:ui';
import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Safety Tips',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeaderSection(),
            const SizedBox(height: 24),

            // Safety categories
            _buildSafetyCategory(
              icon: Icons.person_search,
              title: 'Meeting Someone New',
              color: Colors.blue,
              tips: [
                'Always meet in a public place for the first few meetings',
                'Tell a friend or family member where you\'re going',
                'Keep your phone charged and with you at all times',
                'Trust your instincts - if something feels wrong, leave',
                'Don\'t feel pressured to share personal information',
              ],
            ),
            const SizedBox(height: 16),

            _buildSafetyCategory(
              icon: Icons.lock_outline,
              title: 'Protecting Your Privacy',
              color: Colors.purple,
              tips: [
                'Don\'t share your home address too early',
                'Be cautious about sharing financial information',
                'Use the app\'s messaging system instead of giving out your phone number immediately',
                'Review your profile to ensure you haven\'t shared too much personal info',
                'Be careful about what you share in photos (location tags, identifiable landmarks)',
              ],
            ),
            const SizedBox(height: 16),

            _buildSafetyCategory(
              icon: Icons.warning_outlined,
              title: 'Recognizing Red Flags',
              color: Colors.orange,
              tips: [
                'Requests for money or financial help',
                'Avoiding video calls or in-person meetings',
                'Inconsistent stories or details about their life',
                'Pressure to move communication off the app quickly',
                'Requests for intimate photos or personal documents',
              ],
            ),
            const SizedBox(height: 16),

            _buildSafetyCategory(
              icon: Icons.shopping_bag_outlined,
              title: 'Safe Transactions',
              color: Colors.green,
              tips: [
                'Meet in person to inspect items before buying',
                'Use secure payment methods when possible',
                'Be wary of deals that seem too good to be true',
                'Don\'t send money before receiving goods',
                'Keep records of all communications and transactions',
              ],
            ),
            const SizedBox(height: 16),

            _buildSafetyCategory(
              icon: Icons.report_outlined,
              title: 'Reporting & Blocking',
              color: Colors.red,
              tips: [
                'Report users who violate community guidelines',
                'Block users who make you uncomfortable',
                'Save screenshots of concerning messages before reporting',
                'Don\'t engage with harassment - report and block instead',
                'Contact support if you experience serious issues',
              ],
            ),
            const SizedBox(height: 24),

            // Emergency contact section
            _buildEmergencySection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.2), Colors.purple.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, color: Colors.blue, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Safety Matters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Follow these tips to stay safe while using Supper',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCategory({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> tips,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: color.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Text(
                'In Case of Emergency',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'If you feel you are in immediate danger, please contact your local emergency services immediately.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone, color: Colors.white.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 8),
              Text(
                'Emergency: 911 (US) / 112 (EU) / 999 (UK)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
