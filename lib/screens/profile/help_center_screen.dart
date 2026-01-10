import 'dart:ui';
import 'package:flutter/material.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  final List<_HelpCategory> _categories = [
    _HelpCategory(
      title: 'Getting Started',
      icon: Icons.rocket_launch,
      color: Colors.blue,
      faqs: [
        _FAQ(
          question: 'What is Supper?',
          answer: 'Supper is an AI-powered matching app that connects people for various purposes - whether you\'re buying, selling, looking for friends, dating, finding jobs, or reuniting lost items with their owners. Our smart AI understands your intent and finds the best matches for you.',
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

  List<_HelpCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;

    return _categories.map((category) {
      final filteredFaqs = category.faqs.where((faq) =>
        faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        faq.answer.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();

      return _HelpCategory(
        title: category.title,
        icon: category.icon,
        color: category.color,
        faqs: filteredFaqs,
      );
    }).where((category) => category.faqs.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Help Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search for help...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          // Categories and FAQs
          Expanded(
            child: _filteredCategories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCategories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = _filteredCategories[categoryIndex];
                      return _buildCategorySection(category, categoryIndex);
                    },
                  ),
          ),

          // Contact support button
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContactSupportButton(),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: category.color, size: 20),
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

  Widget _buildContactSupportButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
                child: const Icon(Icons.support_agent, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Still need help?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Contact our support team',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
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
