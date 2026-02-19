import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/main_navigation_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _expandedIndex;

  final List<_HelpCategory> _categories = [
    _HelpCategory(
      title: 'Getting Started',
      icon: Icons.rocket_launch,
      color: Colors.blue,
      faqs: [
        _FAQ(
          question: 'What is SingleTap?',
          answer: 'SingleTap is an AI-powered matching app that connects people for various purposes - whether you\'re buying, selling, looking for friends, dating, finding jobs, or reuniting lost items with their owners. Our smart AI understands your intent and finds the best matches for you.',
        ),
        _FAQ(
          question: 'How do I create a post?',
          answer: 'Simply type what you\'re looking for or offering in the Home screen\'s chat interface. Our AI will understand your intent and create a post automatically. You can also tap the + button to create a detailed post manually.',
        ),
        _FAQ(
          question: 'How does matching work?',
          answer: 'Our AI uses semantic understanding to match you with compatible users. It considers intent complementarity (e.g., buyer with seller), location proximity, price compatibility, and shared interests to find the best matches.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Account & Profile',
      icon: Icons.person_outline,
      color: Colors.purple,
      faqs: [
        _FAQ(
          question: 'How do I edit my profile?',
          answer: 'Go to Profile tab > Settings > Edit Profile. You can update your name, photo, bio, interests, and location preferences.',
        ),
        _FAQ(
          question: 'How do I switch to a Business account?',
          answer: 'Go to Profile tab > Settings > Account Type and select "Business Account". This unlocks features like analytics, multiple posts, and business verification.',
        ),
        _FAQ(
          question: 'How do I delete my account?',
          answer: 'Go to Profile tab > Settings > Security > Delete Account. Note that this action is permanent and cannot be undone.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Connections & Messaging',
      icon: Icons.chat_bubble_outline,
      color: Colors.green,
      faqs: [
        _FAQ(
          question: 'How do I connect with someone?',
          answer: 'When you find a match, tap "Connect" to send a connection request. Once they accept, you can start chatting and even make voice calls.',
        ),
        _FAQ(
          question: 'Can I make voice calls?',
          answer: 'Yes! Once you\'re connected with someone, you can make voice calls through the app. Just open the chat and tap the phone icon.',
        ),
        _FAQ(
          question: 'How do I block someone?',
          answer: 'In the chat screen, tap the menu icon (three dots) and select "Block User". You can manage blocked users in Settings > Blocked Users.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Live Connect',
      icon: Icons.people_outline,
      color: Colors.orange,
      faqs: [
        _FAQ(
          question: 'What is Live Connect?',
          answer: 'Live Connect shows you people nearby who are actively looking to connect. You can filter by categories like Dating, Friendship, Business, or Sports.',
        ),
        _FAQ(
          question: 'How do I appear on Live Connect?',
          answer: 'Make sure "Discoverable on Live Connect" is enabled in Settings. Your profile will appear to others based on your location and active posts.',
        ),
        _FAQ(
          question: 'Why can\'t I see anyone nearby?',
          answer: 'Make sure location services are enabled for the app. Also check your filter settings - you might have filters that are too restrictive.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Privacy & Safety',
      icon: Icons.shield_outlined,
      color: Colors.red,
      faqs: [
        _FAQ(
          question: 'Is my location shared with others?',
          answer: 'We show only your city name to other users, never your exact GPS coordinates. You can manage location settings in Settings > Location.',
        ),
        _FAQ(
          question: 'How do I report inappropriate behavior?',
          answer: 'Tap the menu icon in any chat or profile and select "Report". Our team reviews all reports and takes appropriate action.',
        ),
        _FAQ(
          question: 'Are my messages encrypted?',
          answer: 'Yes, all messages are transmitted securely and stored with encryption in our cloud infrastructure.',
        ),
      ],
    ),
    _HelpCategory(
      title: 'Troubleshooting',
      icon: Icons.build_outlined,
      color: Colors.teal,
      faqs: [
        _FAQ(
          question: 'The app is running slowly',
          answer: 'Try clearing the cache in Settings > Clear Cache. Also make sure you have the latest version of the app installed.',
        ),
        _FAQ(
          question: 'I\'m not receiving notifications',
          answer: 'Check that notifications are enabled in your device settings and in the app\'s notification settings. Also ensure "Do Not Disturb" is off.',
        ),
        _FAQ(
          question: 'Voice calls aren\'t connecting',
          answer: 'Make sure both users have a stable internet connection. Try switching between WiFi and mobile data. Also check that microphone permissions are granted.',
        ),
      ],
    ),
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
            });
          },
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/logo/home_background.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.grey.shade900, Colors.black],
                    ),
                  ),
                );
              },
            ),
          ),

          // Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Categories and FAQs
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = _categories[categoryIndex];
                      return _buildCategorySection(category, categoryIndex);
                    },
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(_HelpCategory category, int categoryIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...category.faqs.asMap().entries.map((entry) {
          final faqIndex = entry.key;
          final faq = entry.value;
          final globalIndex = categoryIndex * 100 + faqIndex;

          return _buildFAQItem(faq, globalIndex, category.color);
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFAQItem(_FAQ faq, int index, Color color) {
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  faq.answer,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _HelpCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FAQ> faqs;

  _HelpCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.faqs,
  });
}

class _FAQ {
  final String question;
  final String answer;

  _FAQ({required this.question, required this.answer});
}
