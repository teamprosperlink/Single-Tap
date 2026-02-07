import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/universal_intent_service.dart';
import '../../models/user_profile.dart';
import '../chat/enhanced_chat_screen.dart';
import '../../widgets/other widgets/user_avatar.dart';
import '../../services/realtime_matching_service.dart';
import '../../services/profile services/photo_cache_service.dart';
import '../../widgets/app_background.dart';
import 'product_detail_screen.dart';

@immutable
class HomeScreen extends StatefulWidget {
  /// Global key to access HomeScreenState from outside
  static final GlobalKey<HomeScreenState> globalKey = GlobalKey<HomeScreenState>();

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final UniversalIntentService _intentService = UniversalIntentService();
  final RealtimeMatchingService _realtimeService = RealtimeMatchingService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PhotoCacheService _photoCache = PhotoCacheService();

  final TextEditingController _intentController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();

  bool _isSearchFocused = false;
  bool _isProcessing = false;

  final List<String> _suggestions = [];
  List<Map<String, dynamic>> _matches = [];
  String _currentUserName = '';

  late AnimationController _controller;
  final bool _visible = true;
  Timer? _timer;

  final List<Map<String, dynamic>> _conversation = [];

  // Current chat ID for auto-save (ChatGPT style)
  String? _currentChatId;

  // Voice recording state
  bool _isRecording = false;
  bool _isVoiceProcessing = false;
  Timer? _recordingTimer;

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _currentSpeechText = '';

  @override
  void initState() {
    super.initState();
    _loadUserIntents();
    _loadUserProfile();
    _realtimeService.initialize();
    _initSpeech();

    _controller = AnimationController(vsync: this);

    _searchFocusNode.addListener(_onFocusChange);

    _conversation.add({
      'text':
          'Hi! I\'m your Supper assistant. What would you like to find today?',
      'isUser': false,
      'timestamp': DateTime.now(),
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChange);
    _intentController.dispose();
    _searchFocusNode.dispose();
    _realtimeService.dispose();
    _controller.dispose();
    _timer?.cancel();
    _recordingTimer?.cancel();
    _chatScrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Reset for new chat (ChatGPT style - conversation is auto-saved)
  Future<void> saveConversationAndReset() async {
    debugPrint('Starting new chat (previous auto-saved)');
    _resetConversation();
  }

  /// Load a conversation from chat history
  Future<void> loadConversation(String chatId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chat_history')
          .doc(chatId)
          .get();

      if (!doc.exists) {
        debugPrint('Chat not found: $chatId');
        return;
      }

      final data = doc.data()!;
      final messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);

      setState(() {
        _conversation.clear();
        _matches.clear();
        _intentController.clear();
        _currentChatId = chatId;

        // Restore messages
        for (var msg in messages) {
          _conversation.add({
            'text': msg['text'],
            'isUser': msg['isUser'],
            'timestamp': msg['timestamp'] is Timestamp
                ? (msg['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            'type': msg['type'],
            'data': msg['data'],
          });
        }
      });

      debugPrint('Loaded conversation: $chatId with ${messages.length} messages');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Error loading conversation: $e');
    }
  }

  /// Reset conversation to initial state
  void _resetConversation() {
    setState(() {
      _conversation.clear();
      _matches.clear();
      _intentController.clear();
      _currentChatId = null; // Reset chat ID for new conversation

      // Add welcome message
      _conversation.add({
        'text': 'Hi! I\'m your Supper assistant. What would you like to find today?',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  /// Check if there's an active conversation worth saving
  bool get hasActiveConversation {
    return _conversation.any((msg) => msg['isUser'] == true);
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserName = userDoc.data()?['name'] ?? 'User';
        });
      }
    }
  }

  Future<void> _loadUserIntents() async {
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _intentService.getUserIntents(userId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _processIntent() async {
    if (_intentController.text.isEmpty) return;

    final userMessage = _intentController.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _conversation.add({
        'text': userMessage,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isProcessing = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _intentController.clear();

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    final aiResponse = _generateAIResponse(userMessage);

    setState(() {
      _conversation.add({
        'text': aiResponse,
        'isUser': false,
        'timestamp': DateTime.now(),
      });

      final lowerMessage = userMessage.toLowerCase();

      // If food query, add food results to conversation
      if (_isFoodQuery(lowerMessage)) {
        final foodResults = _getFoodResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'food_results',
          'data': foodResults,
        });
      }
      // If electric query, add electric results
      else if (_isElectricQuery(lowerMessage)) {
        final electricResults = _getElectricResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'electric_results',
          'data': electricResults,
        });
      }
      // If house query, add house results
      else if (_isHouseQuery(lowerMessage)) {
        final houseResults = _getHouseResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'house_results',
          'data': houseResults,
        });
      }
      // If place query, add place results
      else if (_isPlaceQuery(lowerMessage)) {
        final placeResults = _getPlaceResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'place_results',
          'data': placeResults,
        });
      }
      // If news query, add news results
      else if (_isNewsQuery(lowerMessage)) {
        final newsResults = _getNewsResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'news_results',
          'data': newsResults,
        });
      }
      // If reels query, add reels results
      else if (_isReelsQuery(lowerMessage)) {
        final reelsResults = _getReelsResults(userMessage);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'reels_results',
          'data': reelsResults,
        });
      }

      _isProcessing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    if (_shouldProcessForMatches(userMessage)) {
      await _processWithIntent(userMessage);
    }

    // Auto-save conversation to chat history (ChatGPT style)
    await _autoSaveConversation(userMessage);
  }

  /// Auto-save conversation after each message (ChatGPT style)
  Future<void> _autoSaveConversation(String userMessage) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final messagesToSave = _conversation.map((msg) {
        // Convert DateTime to Timestamp for Firestore
        final timestamp = msg['timestamp'];
        final firestoreTimestamp = timestamp is DateTime
            ? Timestamp.fromDate(timestamp)
            : timestamp;

        return <String, dynamic>{
          'text': msg['text'],
          'isUser': msg['isUser'],
          'timestamp': firestoreTimestamp,
          'type': msg['type'],
          'data': msg['data'],
        };
      }).toList();

      // Get title from first user message
      final userMessages = _conversation.where((msg) => msg['isUser'] == true).toList();
      final firstUserMessage = userMessages.isNotEmpty
          ? userMessages.first['text'] as String? ?? 'Chat'
          : userMessage;
      final title = firstUserMessage.length > 50
          ? '${firstUserMessage.substring(0, 50)}...'
          : firstUserMessage;

      if (_currentChatId == null) {
        // Create new chat history document
        final docRef = await FirebaseFirestore.instance.collection('chat_history').add({
          'userId': userId,
          'title': title,
          'messages': messagesToSave,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _currentChatId = docRef.id;
        debugPrint('New chat created: $_currentChatId');
        // Note: Drawer will refresh when opened, no need to call refreshChatHistory here
      } else {
        // Update existing chat history document
        await FirebaseFirestore.instance
            .collection('chat_history')
            .doc(_currentChatId)
            .update({
          'messages': messagesToSave,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Chat updated: $_currentChatId');
      }
    } catch (e) {
      debugPrint('Error auto-saving conversation: $e');
    }
  }

  String _generateAIResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') ||
        message.contains('hi') ||
        message.contains('hey')) {
      return 'Hello ${_currentUserName.split(' ')[0]}! How can I help you find what you need today?';
    } else if (_isFoodQuery(message)) {
      return 'Great choice! Here are some nearby restaurants serving delicious food:';
    } else if (_isElectricQuery(message)) {
      return 'Looking for electronics? Here are some great options for you:';
    } else if (_isHouseQuery(message)) {
      return 'Looking for a place to stay? Here are some properties that might interest you:';
    } else if (_isPlaceQuery(message)) {
      return 'Planning a trip? Here are some amazing places to visit:';
    } else if (_isNewsQuery(message)) {
      return 'Here are the latest news updates for you:';
    } else if (_isReelsQuery(message)) {
      return 'Here are some trending reels for you:';
    } else if (message.contains('bike') || message.contains('cycle')) {
      return 'Looking for a bike? I can help you find people selling or renting bicycles in your area. What\'s your budget?';
    } else if (message.contains('book') || message.contains('study')) {
      return 'Need books? Tell me which subject or specific books you\'re looking for, and I\'ll find students who have them.';
    } else if (message.contains('job') ||
        message.contains('work') ||
        message.contains('hire')) {
      return 'Job hunting? Let me know what kind of work you\'re looking for or if you\'re hiring, and I\'ll find relevant matches.';
    } else if (message.contains('sell') || message.contains('buy')) {
      return 'Looking to buy or sell something? Describe what you need, and I\'ll find the perfect match for you!';
    } else if (message.contains('thank') || message.contains('thanks')) {
      return 'You\'re welcome! Let me know if you need help with anything else.';
    } else if (message.contains('help')) {
      return 'I can help you find:\n• Electronics & Gadgets\n• Houses & Properties\n• Hill Stations & Places\n• Food & Restaurants\n• Items to buy/sell\n• Part-time jobs\nJust tell me what you need!';
    } else {
      return 'I understand you\'re looking for: "$userMessage". Let me find the best matches for you in our community!';
    }
  }

  bool _isFoodQuery(String message) {
    final foodKeywords = [
      'food',
      'eat',
      'hungry',
      'restaurant',
      'hotel',
      'pizza',
      'burger',
      'biryani',
      'chicken',
      'paneer',
      'dal',
      'rice',
      'roti',
      'naan',
      'dosa',
      'idli',
      'samosa',
      'chaat',
      'momos',
      'noodles',
      'chinese',
      'italian',
      'mexican',
      'thai',
      'indian',
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'dessert',
      'ice cream',
      'cake',
      'coffee',
      'tea',
      'juice',
      'shake',
      'thali',
      'paratha',
      'chole',
      'pav bhaji',
      'vada pav',
      'sandwich',
      'wrap',
      'roll',
      'fried rice',
      'manchurian',
      'curry',
      'kebab',
      'tandoori',
      'masala',
      'korma',
      'pulao',
    ];
    return foodKeywords.any((keyword) => message.contains(keyword));
  }

  bool _isElectricQuery(String message) {
    final electricKeywords = [
      'electric',
      'electronics',
      'phone',
      'mobile',
      'laptop',
      'computer',
      'tv',
      'television',
      'fridge',
      'refrigerator',
      'ac',
      'air conditioner',
      'washing machine',
      'microwave',
      'fan',
      'cooler',
      'heater',
      'iron',
      'mixer',
      'grinder',
      'blender',
      'toaster',
      'oven',
      'camera',
      'speaker',
      'headphone',
      'earphone',
      'charger',
      'power bank',
      'tablet',
      'ipad',
      'smartwatch',
      'watch',
      'gadget',
      'appliance',
      'led',
      'bulb',
      'light',
    ];
    return electricKeywords.any((keyword) => message.contains(keyword));
  }

  bool _isHouseQuery(String message) {
    final houseKeywords = [
      'house',
      'home',
      'flat',
      'apartment',
      'villa',
      'bungalow',
      'property',
      'real estate',
      'pg',
      'paying guest',
      'hostel',
      '1bhk',
      '2bhk',
      '3bhk',
      '4bhk',
      'bedroom',
      'kitchen',
      'bathroom',
      'balcony',
      'terrace',
      'duplex',
      'penthouse',
      'studio',
      'furnished',
      'unfurnished',
      'semi furnished',
    ];
    return houseKeywords.any((keyword) => message.contains(keyword));
  }

  bool _isPlaceQuery(String message) {
    final placeKeywords = [
      'hill station',
      'hill',
      'mountain',
      'beach',
      'lake',
      'waterfall',
      'temple',
      'mandir',
      'church',
      'mosque',
      'gurudwara',
      'monument',
      'fort',
      'palace',
      'museum',
      'zoo',
      'park',
      'garden',
      'mall',
      'market',
      'tourist',
      'travel',
      'trip',
      'vacation',
      'holiday',
      'resort',
      'camping',
      'trekking',
      'hiking',
      'adventure',
      'shimla',
      'manali',
      'goa',
      'kashmir',
      'kerala',
      'rajasthan',
      'ladakh',
      'ooty',
      'darjeeling',
      'mussoorie',
      'nainital',
      'lonavala',
      'mahabaleshwar',
      'munnar',
      'coorg',
      'rishikesh',
      'varanasi',
      'jaipur',
      'udaipur',
      'agra',
      'delhi',
      'mumbai',
      'kolkata',
      'chennai',
      'bangalore',
      'hyderabad',
      'place',
      'visit',
      'destination',
      'sightseeing',
    ];
    return placeKeywords.any((keyword) => message.contains(keyword));
  }

  bool _isNewsQuery(String message) {
    final newsKeywords = [
      'news',
      'khabar',
      'headline',
      'headlines',
      'latest',
      'breaking',
      'update',
      'updates',
      'today',
      'trending',
      'viral',
      'current affairs',
      'current events',
      'whats happening',
      'what\'s happening',
      'politics',
      'sports',
      'cricket',
      'football',
      'business',
      'tech news',
      'technology news',
      'entertainment',
      'bollywood',
      'hollywood',
      'weather',
      'stock market',
      'election',
      'world news',
      'india news',
      'local news',
    ];
    return newsKeywords.any((keyword) => message.contains(keyword));
  }

  bool _isReelsQuery(String message) {
    final reelsKeywords = [
      'reels',
      'reel',
      'video',
      'videos',
      'shorts',
      'short video',
      'funny video',
      'comedy',
      'meme',
      'memes',
      'entertainment video',
      'watch video',
      'show video',
      'tiktok',
      'instagram reels',
      'youtube shorts',
      'viral video',
      'trending video',
      'dance',
      'music video',
      'song',
      'clip',
      'clips',
    ];
    return reelsKeywords.any((keyword) => message.contains(keyword));
  }

  List<Map<String, dynamic>> _getFoodResults(String query) {
    // Mock food data - in production, this would come from an API
    final allFoods = [
      {
        'name': 'Butter Chicken',
        'restaurant': 'Punjab Grill',
        'rating': 4.5,
        'price': '₹350',
        'image':
            'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=400',
        'distance': '1.2 km',
      },
      {
        'name': 'Margherita Pizza',
        'restaurant': 'Pizza Hut',
        'rating': 4.2,
        'price': '₹299',
        'image':
            'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400',
        'distance': '0.8 km',
      },
      {
        'name': 'Veg Biryani',
        'restaurant': 'Biryani House',
        'rating': 4.3,
        'price': '₹220',
        'image':
            'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400',
        'distance': '2.1 km',
      },
      {
        'name': 'Masala Dosa',
        'restaurant': 'South Indian Cafe',
        'rating': 4.6,
        'price': '₹120',
        'image':
            'https://images.unsplash.com/photo-1668236543090-82eb5eace9f8?w=400',
        'distance': '0.5 km',
      },
      {
        'name': 'Chicken Momos',
        'restaurant': 'Momo Junction',
        'rating': 4.4,
        'price': '₹150',
        'image':
            'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=400',
        'distance': '1.5 km',
      },
      {
        'name': 'Paneer Tikka',
        'restaurant': 'Tandoor Nights',
        'rating': 4.3,
        'price': '₹280',
        'image':
            'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400',
        'distance': '1.8 km',
      },
      {
        'name': 'Classic Burger',
        'restaurant': 'Burger King',
        'rating': 4.1,
        'price': '₹199',
        'image':
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        'distance': '0.6 km',
      },
      {
        'name': 'Chole Bhature',
        'restaurant': 'Delhi Darbar',
        'rating': 4.5,
        'price': '₹180',
        'image':
            'https://images.unsplash.com/photo-1626132647523-66c4bf1e8e5c?w=400',
        'distance': '1.0 km',
      },
    ];

    final lowerQuery = query.toLowerCase();

    // Filter based on query or return all
    return allFoods.where((food) {
      final name = (food['name'] as String).toLowerCase();
      final restaurant = (food['restaurant'] as String).toLowerCase();
      return name.contains(lowerQuery) ||
          restaurant.contains(lowerQuery) ||
          lowerQuery.contains('food') ||
          lowerQuery.contains('eat') ||
          lowerQuery.contains('hungry') ||
          lowerQuery.contains('restaurant');
    }).toList();
  }

  List<Map<String, dynamic>> _getElectricResults(String query) {
    final allElectrics = [
      {
        'name': 'iPhone 15 Pro',
        'brand': 'Apple',
        'rating': 4.8,
        'price': '₹1,34,900',
        'image':
            'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400',
        'condition': 'New',
      },
      {
        'name': 'MacBook Air M2',
        'brand': 'Apple',
        'rating': 4.9,
        'price': '₹1,14,900',
        'image':
            'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400',
        'condition': 'New',
      },
      {
        'name': 'Samsung Smart TV 55"',
        'brand': 'Samsung',
        'rating': 4.5,
        'price': '₹54,990',
        'image':
            'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=400',
        'condition': 'New',
      },
      {
        'name': 'Sony WH-1000XM5',
        'brand': 'Sony',
        'rating': 4.7,
        'price': '₹29,990',
        'image':
            'https://images.unsplash.com/photo-1546435770-a3e426bf472b?w=400',
        'condition': 'New',
      },
      {
        'name': 'LG Refrigerator 260L',
        'brand': 'LG',
        'rating': 4.4,
        'price': '₹28,990',
        'image':
            'https://images.unsplash.com/photo-1571175443880-49e1d25b2bc5?w=400',
        'condition': 'New',
      },
      {
        'name': 'Dyson Air Purifier',
        'brand': 'Dyson',
        'rating': 4.6,
        'price': '₹42,900',
        'image':
            'https://images.unsplash.com/photo-1585771724684-38269d6639fd?w=400',
        'condition': 'New',
      },
      {
        'name': 'Canon EOS R6',
        'brand': 'Canon',
        'rating': 4.8,
        'price': '₹2,15,995',
        'image':
            'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=400',
        'condition': 'New',
      },
      {
        'name': 'iPad Pro 12.9"',
        'brand': 'Apple',
        'rating': 4.9,
        'price': '₹1,12,900',
        'image':
            'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=400',
        'condition': 'New',
      },
    ];

    return allElectrics;
  }

  List<Map<String, dynamic>> _getHouseResults(String query) {
    final allHouses = [
      {
        'name': '3 BHK Luxury Apartment',
        'location': 'Bandra West, Mumbai',
        'rating': 4.6,
        'price': '₹2.5 Cr',
        'image':
            'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=400',
        'type': 'Apartment',
        'area': '1450 sq.ft',
      },
      {
        'name': '2 BHK Furnished Flat',
        'location': 'Koramangala, Bangalore',
        'rating': 4.4,
        'price': '₹45,000/mo',
        'image':
            'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400',
        'type': 'Flat',
        'area': '1100 sq.ft',
      },
      {
        'name': 'Premium Villa',
        'location': 'Jubilee Hills, Hyderabad',
        'rating': 4.8,
        'price': '₹4.2 Cr',
        'image':
            'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=400',
        'type': 'Villa',
        'area': '3200 sq.ft',
      },
      {
        'name': '1 BHK Studio Apartment',
        'location': 'Andheri East, Mumbai',
        'rating': 4.2,
        'price': '₹18,000/mo',
        'image':
            'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400',
        'type': 'Studio',
        'area': '550 sq.ft',
      },
      {
        'name': 'Duplex Penthouse',
        'location': 'Golf Course Road, Gurgaon',
        'rating': 4.9,
        'price': '₹6.8 Cr',
        'image':
            'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=400',
        'type': 'Penthouse',
        'area': '4500 sq.ft',
      },
      {
        'name': 'PG for Girls',
        'location': 'HSR Layout, Bangalore',
        'rating': 4.3,
        'price': '₹12,000/mo',
        'image':
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400',
        'type': 'PG',
        'area': 'Single Room',
      },
      {
        'name': '4 BHK Independent House',
        'location': 'Sector 50, Noida',
        'rating': 4.5,
        'price': '₹1.8 Cr',
        'image':
            'https://images.unsplash.com/photo-1605146769289-440113cc3d00?w=400',
        'type': 'House',
        'area': '2800 sq.ft',
      },
      {
        'name': 'Beachfront Apartment',
        'location': 'Marine Drive, Mumbai',
        'rating': 4.7,
        'price': '₹5.5 Cr',
        'image':
            'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400',
        'type': 'Apartment',
        'area': '2100 sq.ft',
      },
    ];

    return allHouses;
  }

  List<Map<String, dynamic>> _getPlaceResults(String query) {
    final allPlaces = [
      {
        'name': 'Manali',
        'location': 'Himachal Pradesh',
        'rating': 4.7,
        'price': '₹8,500',
        'image':
            'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?w=400',
        'type': 'Hill Station',
        'distance': '540 km',
      },
      {
        'name': 'Goa Beaches',
        'location': 'Goa',
        'rating': 4.8,
        'price': '₹12,000',
        'image':
            'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=400',
        'type': 'Beach',
        'distance': '590 km',
      },
      {
        'name': 'Shimla',
        'location': 'Himachal Pradesh',
        'rating': 4.6,
        'price': '₹6,500',
        'image':
            'https://images.unsplash.com/photo-1597074866923-dc0589150358?w=400',
        'type': 'Hill Station',
        'distance': '350 km',
      },
      {
        'name': 'Taj Mahal',
        'location': 'Agra, UP',
        'rating': 4.9,
        'price': '₹50',
        'image':
            'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=400',
        'type': 'Monument',
        'distance': '230 km',
      },
      {
        'name': 'Kerala Backwaters',
        'location': 'Kerala',
        'rating': 4.8,
        'price': '₹15,000',
        'image':
            'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?w=400',
        'type': 'Lake',
        'distance': '2100 km',
      },
      {
        'name': 'Jaipur City Palace',
        'location': 'Rajasthan',
        'rating': 4.7,
        'price': '₹500',
        'image':
            'https://images.unsplash.com/photo-1599661046289-e31897846e41?w=400',
        'type': 'Palace',
        'distance': '280 km',
      },
      {
        'name': 'Rishikesh',
        'location': 'Uttarakhand',
        'rating': 4.6,
        'price': '₹5,000',
        'image':
            'https://images.unsplash.com/photo-1592385862821-d7bfee21be83?w=400',
        'type': 'Adventure',
        'distance': '240 km',
      },
      {
        'name': 'Ladakh',
        'location': 'Jammu & Kashmir',
        'rating': 4.9,
        'price': '₹25,000',
        'image':
            'https://images.unsplash.com/photo-1626015365107-59f71df26e70?w=400',
        'type': 'Mountain',
        'distance': '1020 km',
      },
    ];

    return allPlaces;
  }

  List<Map<String, dynamic>> _getNewsResults(String query) {
    final allNews = [
      {
        'title': 'India Wins Historic Test Series Against Australia',
        'source': 'Sports Today',
        'category': 'Sports',
        'time': '2 hours ago',
        'image':
            'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=400',
        'description':
            'Team India creates history by winning the Border-Gavaskar Trophy for the fifth consecutive time.',
      },
      {
        'title': 'Stock Market Hits All-Time High',
        'source': 'Economic Times',
        'category': 'Business',
        'time': '3 hours ago',
        'image':
            'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=400',
        'description':
            'Sensex crosses 80,000 mark for the first time as FII inflows continue.',
      },
      {
        'title': 'New AI Chip Launched by Tech Giant',
        'source': 'Tech Crunch',
        'category': 'Technology',
        'time': '4 hours ago',
        'image':
            'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400',
        'description':
            'Revolutionary AI chip promises 10x faster processing for machine learning tasks.',
      },
      {
        'title': 'Bollywood Star Announces New Film',
        'source': 'Film Fare',
        'category': 'Entertainment',
        'time': '5 hours ago',
        'image':
            'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400',
        'description':
            'Highly anticipated sequel to blockbuster franchise to release next year.',
      },
      {
        'title': 'Government Launches New Digital Initiative',
        'source': 'India Today',
        'category': 'Politics',
        'time': '6 hours ago',
        'image':
            'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=400',
        'description':
            'New scheme aims to provide digital services to rural areas across the country.',
      },
      {
        'title': 'Heavy Rainfall Expected in Mumbai',
        'source': 'Weather Channel',
        'category': 'Weather',
        'time': '1 hour ago',
        'image':
            'https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=400',
        'description':
            'IMD issues orange alert for Mumbai and surrounding areas for next 48 hours.',
      },
      {
        'title': 'ISRO Plans New Moon Mission',
        'source': 'Science Daily',
        'category': 'Science',
        'time': '7 hours ago',
        'image':
            'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=400',
        'description':
            'Chandrayaan-4 mission announced with advanced rover and sample return capability.',
      },
      {
        'title': 'Startup Raises \$100M in Funding',
        'source': 'Startup News',
        'category': 'Business',
        'time': '8 hours ago',
        'image':
            'https://images.unsplash.com/photo-1559136555-9303baea8ebd?w=400',
        'description':
            'Indian fintech startup becomes unicorn with latest funding round.',
      },
    ];

    final lowerQuery = query.toLowerCase();

    // Filter based on category if specified
    if (lowerQuery.contains('sports') ||
        lowerQuery.contains('cricket') ||
        lowerQuery.contains('football')) {
      return allNews.where((n) => n['category'] == 'Sports').toList();
    } else if (lowerQuery.contains('business') ||
        lowerQuery.contains('stock') ||
        lowerQuery.contains('market')) {
      return allNews.where((n) => n['category'] == 'Business').toList();
    } else if (lowerQuery.contains('tech') ||
        lowerQuery.contains('technology')) {
      return allNews
          .where(
            (n) => n['category'] == 'Technology' || n['category'] == 'Science',
          )
          .toList();
    } else if (lowerQuery.contains('entertainment') ||
        lowerQuery.contains('bollywood') ||
        lowerQuery.contains('hollywood')) {
      return allNews.where((n) => n['category'] == 'Entertainment').toList();
    } else if (lowerQuery.contains('politics') ||
        lowerQuery.contains('government')) {
      return allNews.where((n) => n['category'] == 'Politics').toList();
    } else if (lowerQuery.contains('weather')) {
      return allNews.where((n) => n['category'] == 'Weather').toList();
    }

    return allNews;
  }

  List<Map<String, dynamic>> _getReelsResults(String query) {
    // Sample video URLs (free stock videos)
    final allReels = [
      {
        'title': 'Epic Dance Moves',
        'creator': '@dance_king',
        'views': '2.5M',
        'likes': '150K',
        'thumbnail':
            'https://images.unsplash.com/photo-1547153760-18fc86324498?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'duration': '0:30',
        'category': 'Dance',
      },
      {
        'title': 'Cooking Hack You Need',
        'creator': '@foodie_chef',
        'views': '1.8M',
        'likes': '98K',
        'thumbnail':
            'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        'duration': '0:45',
        'category': 'Food',
      },
      {
        'title': 'Comedy Skit - Office Life',
        'creator': '@funny_guy',
        'views': '5.2M',
        'likes': '320K',
        'thumbnail':
            'https://images.unsplash.com/photo-1527224857830-43a7acc85260?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'duration': '0:58',
        'category': 'Comedy',
      },
      {
        'title': 'Travel Vlog - Goa',
        'creator': '@wanderlust',
        'views': '890K',
        'likes': '67K',
        'thumbnail':
            'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        'duration': '1:20',
        'category': 'Travel',
      },
      {
        'title': 'Fitness Motivation',
        'creator': '@fit_life',
        'views': '3.1M',
        'likes': '210K',
        'thumbnail':
            'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'duration': '0:35',
        'category': 'Fitness',
      },
      {
        'title': 'Cute Pet Moments',
        'creator': '@pet_lover',
        'views': '4.7M',
        'likes': '450K',
        'thumbnail':
            'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        'duration': '0:22',
        'category': 'Pets',
      },
      {
        'title': 'Tech Review - New Phone',
        'creator': '@tech_guru',
        'view  umbnail':
            'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'duration': '0:55',
        'category': 'Tech',
      },
      {
        'title': 'Fashion Tips 2024',
        'creator': '@style_icon',
        'views': '2.8M',
        'likes': '185K',
        'thumbnail':
            'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400',
        'videoUrl':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        'duration': '0:40',
        'category': 'Fashion',
      },
    ];

    final lowerQuery = query.toLowerCase();

    // Filter based on category if specified
    if (lowerQuery.contains('dance') || lowerQuery.contains('music')) {
      return allReels.where((r) => r['category'] == 'Dance').toList();
    } else if (lowerQuery.contains('comedy') ||
        lowerQuery.contains('funny') ||
        lowerQuery.contains('meme')) {
      return allReels.where((r) => r['category'] == 'Comedy').toList();
    } else if (lowerQuery.contains('food') || lowerQuery.contains('cooking')) {
      return allReels.where((r) => r['category'] == 'Food').toList();
    } else if (lowerQuery.contains('travel')) {
      return allReels.where((r) => r['category'] == 'Travel').toList();
    } else if (lowerQuery.contains('fitness') || lowerQuery.contains('gym')) {
      return allReels.where((r) => r['category'] == 'Fitness').toList();
    } else if (lowerQuery.contains('pet') ||
        lowerQuery.contains('dog') ||
        lowerQuery.contains('cat')) {
      return allReels.where((r) => r['category'] == 'Pets').toList();
    } else if (lowerQuery.contains('tech')) {
      return allReels.where((r) => r['category'] == 'Tech').toList();
    } else if (lowerQuery.contains('fashion') || lowerQuery.contains('style')) {
      return allReels.where((r) => r['category'] == 'Fashion').toList();
    }

    return allReels;
  }

  bool _shouldProcessForMatches(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('bike') ||
        lowerMessage.contains('book') ||
        lowerMessage.contains('room') ||
        lowerMessage.contains('job') ||
        lowerMessage.contains('sell') ||
        lowerMessage.contains('buy') ||
        lowerMessage.contains('rent') ||
        lowerMessage.contains('hire') ||
        lowerMessage.contains('find') ||
        lowerMessage.contains('look');
  }

  // Mock voice results for fallback
  final List<String> _mockVoiceResults = [
    "I'm looking for a bicycle under 200 dollars",
    "Need a room for rent near college campus",
    "Want to buy second hand engineering books",
    "Looking for part time job on weekends",
    "Selling my old smartphone in good condition",
    "Want to find a roommate near university",
    "Looking to buy a used laptop for studies",
  ];

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRecording) {
              _finishRecording();
            }
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          if (mounted && _isRecording) {
            // Fall back to mock data on error
            _useMockVoiceResult();
          }
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  void _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _currentSpeechText = '';
    });

    if (_speechEnabled) {
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted && result.recognizedWords.isNotEmpty) {
              setState(() {
                _currentSpeechText = result.recognizedWords;
              });
              // Auto-finish when speech is final
              if (result.finalResult && _currentSpeechText.isNotEmpty) {
                _finishRecording();
              }
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      } catch (e) {
        debugPrint('Error starting speech: $e');
        // Fall back to mock after delay
        _recordingTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _isRecording) {
            _useMockVoiceResult();
          }
        });
      }
    } else {
      // Speech not available, use mock after delay
      _recordingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _isRecording) {
          _useMockVoiceResult();
        }
      });
    }
  }

  void _stopVoiceRecording() async {
    HapticFeedback.lightImpact();
    _recordingTimer?.cancel();

    if (_speechEnabled) {
      await _speech.stop();
    }

    _finishRecording();
  }

  void _useMockVoiceResult() {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final randomResult =
        _mockVoiceResults[DateTime.now().millisecondsSinceEpoch %
            _mockVoiceResults.length];

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = false;
      _conversation.add({
        'text': randomResult,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _processVoiceMessage(randomResult);
  }

  void _finishRecording() {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final spokenText = _currentSpeechText.trim();

    setState(() {
      _isRecording = false;
      _isVoiceProcessing = spokenText.isNotEmpty;
    });

    // If no speech detected, use mock data
    if (spokenText.isEmpty) {
      _useMockVoiceResult();
      return;
    }

    // Add voice result to chat
    setState(() {
      _isVoiceProcessing = false;
      _conversation.add({
        'text': spokenText,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Process for AI response
    _processVoiceMessage(spokenText);
  }

  void _processVoiceMessage(String message) async {
    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    final aiResponse = _generateAIResponse(message);
    final lowerMessage = message.toLowerCase();

    setState(() {
      _conversation.add({
        'text': aiResponse,
        'isUser': false,
        'timestamp': DateTime.now(),
      });

      // Add results based on query type
      if (_isFoodQuery(lowerMessage)) {
        final foodResults = _getFoodResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'food_results',
          'data': foodResults,
        });
      } else if (_isElectricQuery(lowerMessage)) {
        final electricResults = _getElectricResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'electric_results',
          'data': electricResults,
        });
      } else if (_isHouseQuery(lowerMessage)) {
        final houseResults = _getHouseResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'house_results',
          'data': houseResults,
        });
      } else if (_isPlaceQuery(lowerMessage)) {
        final placeResults = _getPlaceResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'place_results',
          'data': placeResults,
        });
      } else if (_isNewsQuery(lowerMessage)) {
        final newsResults = _getNewsResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'news_results',
          'data': newsResults,
        });
      } else if (_isReelsQuery(lowerMessage)) {
        final reelsResults = _getReelsResults(message);
        _conversation.add({
          'text': '',
          'isUser': false,
          'timestamp': DateTime.now(),
          'type': 'reels_results',
          'data': reelsResults,
        });
      }

      _isProcessing = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    if (_shouldProcessForMatches(message)) {
      await _processWithIntent(message);
    }
  }

  Future<void> _processWithIntent(String intent) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _intentService.processIntentAndMatch(intent);

      if (!mounted) return;

      if (result['success'] == true) {
        final matches = List<Map<String, dynamic>>.from(
          result['matches'] ?? [],
        );

        for (final match in matches) {
          final userProfile = match['userProfile'] ?? {};
          final userId = match['userId'];
          final photoUrl = userProfile['photoUrl'];

          if (userId != null && photoUrl != null) {
            _photoCache.cachePhotoUrl(userId, photoUrl);
          }
        }

        setState(() {
          _matches = matches;
          _isProcessing = false;
        });

        if (_matches.isNotEmpty) {
          setState(() {
            _conversation.add({
              'text':
                  'Found ${_matches.length} potential matches for you! Tap below to view them.',
              'isUser': false,
              'timestamp': DateTime.now(),
            });
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        _loadUserIntents();
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)}m away';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceInKm.toStringAsFixed(0)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color.fromARGB(255, 243, 236, 236),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        centerTitle: false,
        leadingWidth: 56,
        title: const SizedBox.shrink(),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        showParticles: true,
        overlayOpacity: 0.6,
        child: Column(
          children: [
            Expanded(
              child: _isProcessing
                  ? _buildChatState(isDarkMode)
                  : _matches.isNotEmpty
                  ? _buildMatchesList(isDarkMode)
                  : _buildChatState(isDarkMode),
            ),

            // Bottom input section (always visible, recording happens inline)
            _buildInputSection(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(bool isDarkMode) {
    // Add padding for safe area (no bottom nav bar anymore - it's now a top TabBar)
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding + 16,
        top: 16,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _intentController.text = _suggestions[index];
                        _processIntent();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2),
                              Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _suggestions[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Input container with glassmorphism
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Text field OR Audio wave when recording
                    Expanded(
                      child: (_isRecording || _isVoiceProcessing)
                          ? Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  // Recording indicator dot
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _visible
                                          ? Colors.red
                                          : Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Audio wave bars
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: List.generate(10, (index) {
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: 3,
                                          height: _visible
                                              ? (6.0 +
                                                    ((index % 3 == 0
                                                        ? 18.0
                                                        : (index % 2 == 0
                                                              ? 12.0
                                                              : 8.0))))
                                              : (6.0 +
                                                    ((index % 3 == 0
                                                        ? 8.0
                                                        : (index % 2 == 0
                                                              ? 16.0
                                                              : 10.0)))),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Recording text - show real-time speech
                                  Flexible(
                                    child: Text(
                                      _isVoiceProcessing
                                          ? 'Processing...'
                                          : _currentSpeechText.isNotEmpty
                                          ? _currentSpeechText
                                          : 'Listening...',
                                      style: TextStyle(
                                        color: _currentSpeechText.isNotEmpty
                                            ? Colors.white
                                            : Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                color: _isSearchFocused
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontSize: _isSearchFocused ? 16 : 15,
                                fontWeight: _isSearchFocused
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                height: 1.4,
                              ),
                              child: TextField(
                                cursorHeight: 17,
                                controller: _intentController,
                                focusNode: _searchFocusNode,
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.text,
                                maxLines: 1,
                                cursorWidth: 2,
                                cursorColor: Colors.white,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ask me anything...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.transparent,
                                ),
                                // Don't call setState on every keystroke - causes focus loss
                                onSubmitted: (_) => _processIntent(),
                              ),
                            ),
                    ),

                    const SizedBox(width: 8),

                    // Stop button when recording, Mic button otherwise
                    if (_isRecording || _isVoiceProcessing) ...[
                      // Stop button
                      GestureDetector(
                        onTap: _stopVoiceRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(bottom: 7.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Normal mic button
                      GestureDetector(
                        onTap: _startVoiceRecording,
                        child: Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(left: 6, bottom: 7.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),

                    // Send button
                    GestureDetector(
                      onTap: _isProcessing ? null : _processIntent,
                      child: Container(
                        width: 50,
                        height: 40,
                        margin: const EdgeInsets.only(right: 6, bottom: 7.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[800],
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatState(bool isDarkMode) {
    return Column(
      children: [
        const SizedBox(height: 110),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            reverse: false,
            itemCount: _conversation.length,
            itemBuilder: (context, index) {
              final message = _conversation[index];
              return _buildMessageBubble(message, isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isDarkMode) {
    final isUser = message['isUser'] as bool;
    final text = message['text'] as String;
    final type = message['type'] as String?;

    // If it's a food results message, show food cards
    if (type == 'food_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildResultsWidget(data, isDarkMode, 'food');
    }
    // If it's an electric results message, show electric cards
    if (type == 'electric_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildResultsWidget(data, isDarkMode, 'electric');
    }
    // If it's a house results message, show house cards
    if (type == 'house_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildResultsWidget(data, isDarkMode, 'house');
    }
    // If it's a place results message, show place cards
    if (type == 'place_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildResultsWidget(data, isDarkMode, 'place');
    }
    // If it's a news results message, show news cards
    if (type == 'news_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildNewsResultsWidget(data, isDarkMode);
    }
    // If it's a reels results message, show reels cards
    if (type == 'reels_results') {
      final rawData = message['data'];
      if (rawData == null) return const SizedBox.shrink();
      final data = (rawData as List).cast<Map<String, dynamic>>();
      return _buildReelsResultsWidget(data, isDarkMode);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/logo/Clogo.jpeg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: isUser
                    ? const Radius.circular(20)
                    : const Radius.circular(4),
                bottomRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    // Gradient for chat bubbles
                    gradient: isUser
                        ? LinearGradient(
                            colors: [
                              Colors.blue.withValues(alpha: 0.6),
                              Colors.purple.withValues(alpha: 0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    border: Border.all(
                      color: isUser
                          ? Colors.blue.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? Colors.blue.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
                      height: 1.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: _auth.currentUser?.photoURL != null
                    ? DecorationImage(
                        image: NetworkImage(_auth.currentUser!.photoURL!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: _auth.currentUser?.photoURL == null ? Colors.grey : null,
              ),
              child: _auth.currentUser?.photoURL == null
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildResultsWidget(
    List<Map<String, dynamic>> data,
    bool isDarkMode,
    String category,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrollable cards
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return _buildItemCard(item, isDarkMode, category);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsResultsWidget(
    List<Map<String, dynamic>> data,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrollable news cards
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return _buildNewsCard(item, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> item, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Show news detail bottom sheet
        _showNewsDetail(item);
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                item['image'] as String,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[700],
                    child: const Icon(
                      Icons.newspaper,
                      color: Colors.white54,
                      size: 40,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 100,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        item['category'] as String,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['category'] as String,
                      style: TextStyle(
                        color: _getCategoryColor(item['category'] as String),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Source & Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[500],
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item['time'] as String,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Sports':
        return Colors.orange;
      case 'Business':
        return Colors.green;
      case 'Technology':
        return Colors.blue;
      case 'Science':
        return Colors.purple;
      case 'Entertainment':
        return Colors.pink;
      case 'Politics':
        return Colors.red;
      case 'Weather':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  void _showNewsDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.network(
                item['image'] as String,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[700],
                    child: const Icon(
                      Icons.newspaper,
                      color: Colors.white54,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category & Time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(
                              item['category'] as String,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item['category'] as String,
                            style: TextStyle(
                              color: _getCategoryColor(
                                item['category'] as String,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          color: Colors.grey[500],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['time'] as String,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Source
                    Row(
                      children: [
                        const Icon(Icons.source, color: Colors.blue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          item['source'] as String,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Description
                    Text(
                      item['description'] as String,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Read More Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening full article...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getCategoryColor(
                            item['category'] as String,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Read Full Article',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelsResultsWidget(
    List<Map<String, dynamic>> data,
    bool isDarkMode,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrollable reels cards
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return _buildReelCard(item, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReelCard(Map<String, dynamic> item, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showReelPlayer(item);
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900]?.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item['thumbnail'] as String,
                height: 260,
                width: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 260,
                    width: 150,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white54,
                      size: 50,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 260,
                    width: 150,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            // Play button
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item['duration'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Center play icon
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Creator
                    Text(
                      item['creator'] as String,
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    // Views & Likes
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.grey[500],
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item['views'] as String,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.favorite, color: Colors.red[400], size: 11),
                        const SizedBox(width: 3),
                        Text(
                          item['likes'] as String,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReelPlayer(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _ReelPlayerScreen(reel: item)),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    String category,
  ) {
    // Get icon based on category
    IconData getIcon() {
      switch (category) {
        case 'food':
          return Icons.restaurant;
        case 'electric':
          return Icons.devices;
        case 'house':
          return Icons.home;
        case 'place':
          return Icons.place;
        default:
          return Icons.category;
      }
    }

    // Get subtitle based on category
    String getSubtitle() {
      switch (category) {
        case 'food':
          return item['restaurant'] as String? ?? '';
        case 'electric':
          return item['brand'] as String? ?? '';
        case 'house':
          return item['location'] as String? ?? '';
        case 'place':
          return item['location'] as String? ?? '';
        default:
          return '';
      }
    }

    // Get bottom info based on category
    String getBottomInfo() {
      switch (category) {
        case 'food':
          return item['distance'] as String? ?? '';
        case 'electric':
          return item['condition'] as String? ?? '';
        case 'house':
          return item['area'] as String? ?? '';
        case 'place':
          return item['distance'] as String? ?? '';
        default:
          return '';
      }
    }

    // Get bottom icon based on category
    IconData getBottomIcon() {
      switch (category) {
        case 'food':
          return Icons.location_on;
        case 'electric':
          return Icons.verified;
        case 'house':
          return Icons.square_foot;
        case 'place':
          return Icons.directions;
        default:
          return Icons.info;
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to unified detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailScreen(item: item, category: category),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                item['image'] as String,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[700],
                    child: Icon(getIcon(), color: Colors.white54, size: 40),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 100,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Subtitle (restaurant/brand/location)
                  Text(
                    getSubtitle(),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Price & Rating Row
                  Row(
                    children: [
                      // Price
                      Expanded(
                        child: Text(
                          item['price'] as String,
                          style: TextStyle(
                            color: Colors.green[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rating
                      Icon(Icons.star, color: Colors.amber[400], size: 14),
                      const SizedBox(width: 2),
                      Text(
                        '${item['rating']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Bottom info (distance/condition/area)
                  Row(
                    children: [
                      Icon(getBottomIcon(), color: Colors.grey[500], size: 12),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          getBottomInfo(),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesList(bool isDarkMode) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: Colors.green.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                '${_matches.length} Matches Found',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _matches.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _matches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(_matches[index], isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match, bool isDarkMode) {
    final userProfile = match['userProfile'] ?? {};
    final matchScore = (match['matchScore'] ?? 0.0) * 100;
    final userName = userProfile['name'] ?? 'Unknown User';
    final userId = match['userId'];

    final cachedPhoto = userId != null
        ? _photoCache.getCachedPhotoUrl(userId)
        : null;
    final photoUrl = cachedPhoto ?? userProfile['photoUrl'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();

          final otherUser = UserProfile.fromMap(userProfile, match['userId']);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedChatScreen(otherUser: otherUser),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    profileImageUrl: photoUrl,
                    radius: 24,
                    fallbackText: userName,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${matchScore.toStringAsFixed(0)}% match',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userProfile['city'] != null &&
                            userProfile['city'].toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  userProfile['city'].toString(),
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (match['distance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: Colors.orange[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(match['distance'] as double),
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Posted:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['title'] ??
                          match['description'] ??
                          'Looking for match',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match['description'] != null &&
                        match['description'] != match['title'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          match['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (match['lookingFor'] != null &&
                  match['lookingFor'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Matches your search',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3D Animated Drawer Transition
class Drawer3DTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const Drawer3DTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth = screenWidth * 0.58;

        // Calculate 3D transformation values
        final slideValue = animation.value;
        final rotationAngle =
            (1 - slideValue) * -0.5; // Rotate from -0.5 rad to 0
        final scaleValue = 0.85 + (slideValue * 0.15); // Scale from 0.85 to 1.0
        final translateX = -drawerWidth * (1 - slideValue); // Slide from left

        // Background overlay opacity
        final overlayOpacity = slideValue * 0.6;

        // Main content scale and translate (push effect)
        final mainContentScale = 1.0 - (slideValue * 0.1);
        final mainContentTranslateX = slideValue * drawerWidth * 0.3;
        final mainContentRotation = slideValue * 0.15;

        return Stack(
          children: [
            // Main content with 3D push effect (simulated) - behind everything
            if (slideValue > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..setTranslationRaw(mainContentTranslateX, 0, 0)
                      ..multiply(
                        Matrix4.diagonal3Values(
                          mainContentScale,
                          mainContentScale,
                          1.0,
                        ),
                      )
                      ..rotateY(mainContentRotation),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20 * slideValue),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.3 * slideValue,
                            ),
                            blurRadius: 30,
                            offset: const Offset(-10, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Tap area on the right side to close drawer
            Positioned(
              left: drawerWidth * slideValue,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -10) {
                    Navigator.pop(context);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: overlayOpacity),
                ),
              ),
            ),

            // 3D Drawer with rotation and scale
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002) // Perspective
                  ..setTranslationRaw(translateX, 0, 0)
                  ..rotateY(rotationAngle)
                  ..multiply(
                    Matrix4.diagonal3Values(scaleValue, scaleValue, 1.0),
                  ),
                child: Container(
                  width: drawerWidth,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2 * slideValue),
                        blurRadius: 40,
                        spreadRadius: 5,
                        offset: const Offset(10, 0),
                      ),
                      BoxShadow(
                        color: Colors.purple.withValues(
                          alpha: 0.1 * slideValue,
                        ),
                        blurRadius: 60,
                        spreadRadius: 10,
                        offset: const Offset(20, 0),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: slideValue.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ChatGPT-style Side Drawer
class _ChatHistorySideDrawer extends StatefulWidget {
  final VoidCallback onNewChat;
  final VoidCallback onSearchChats;
  final VoidCallback onLibrary;
  final VoidCallback onProjects;
  final VoidCallback onGroupChat;

  const _ChatHistorySideDrawer({
    required this.onNewChat,
    required this.onSearchChats,
    required this.onLibrary,
    required this.onProjects,
    required this.onGroupChat,
  });

  @override
  State<_ChatHistorySideDrawer> createState() => _ChatHistorySideDrawerState();
}

class _ChatHistorySideDrawerState extends State<_ChatHistorySideDrawer>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _shimmerController;
  late List<Animation<double>> _itemAnimations;

  final List<Map<String, dynamic>> _chatHistory = [
    {
      'title': 'Looking for iPhone 13',
      'time': 'Today',
      'icon': Icons.phone_iphone,
    },
    {
      'title': 'Best restaurants nearby',
      'time': 'Today',
      'icon': Icons.restaurant,
    },
    {
      'title': 'Job search - Developer',
      'time': 'Yesterday',
      'icon': Icons.work_outline,
    },
    {
      'title': 'Apartment for rent',
      'time': 'Yesterday',
      'icon': Icons.home_outlined,
    },
    {
      'title': 'Grocery shopping list',
      'time': 'Last 7 days',
      'icon': Icons.shopping_cart_outlined,
    },
    {
      'title': 'Travel plans',
      'time': 'Last 7 days',
      'icon': Icons.flight_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Stagger animation controller for items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Shimmer animation controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Create staggered animations for each item (total 10 items approx)
    _itemAnimations = List.generate(10, (index) {
      final startTime = index * 0.1;
      final endTime = startTime + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            startTime.clamp(0.0, 1.0),
            endTime.clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        ),
      );
    });

    // Start animation
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.58;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            width: drawerWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              // Glassmorphism - transparent with subtle tint
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.blue.withValues(alpha: 0.05),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              // Glass border - bright edge
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              // Depth shadows
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(8, 0),
                ),
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 60,
                  spreadRadius: -5,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with New Chat button - Animated
                  _buildAnimatedItem(
                    0,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onNewChat();
                        },
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.1),
                                    Colors.blue.withValues(
                                      alpha:
                                          0.15 +
                                          (_shimmerController.value * 0.1),
                                    ),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                  stops: [0.0, _shimmerController.value, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 600),
                                    builder: (context, value, child) {
                                      return Transform.rotate(
                                        angle: (1 - value) * 0.5,
                                        child: Transform.scale(
                                          scale: 0.5 + (value * 0.5),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'New Chat',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Search Bar - Animated
                  _buildAnimatedItem(
                    1,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onSearchChats();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Search chats...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Menu Items (Library, Projects, Group Chat) - Animated
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _buildAnimatedItem(
                          2,
                          _buildMenuItem(
                            Icons.folder_open_outlined,
                            'Library',
                            Colors.orange,
                            widget.onLibrary,
                          ),
                        ),
                        _buildAnimatedItem(
                          3,
                          _buildMenuItem(
                            Icons.folder_special_outlined,
                            'Projects',
                            Colors.purple,
                            widget.onProjects,
                          ),
                        ),
                        _buildAnimatedItem(
                          4,
                          _buildMenuItem(
                            Icons.group_outlined,
                            'Group Chats',
                            Colors.green,
                            widget.onGroupChat,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Chat History List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount:
                          _chatHistory.length + 3, // +3 for section headers
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildSectionHeader('Today');
                        } else if (index <= 2) {
                          return _buildChatItem(_chatHistory[index - 1]);
                        } else if (index == 3) {
                          return _buildSectionHeader('Yesterday');
                        } else if (index <= 5) {
                          return _buildChatItem(_chatHistory[index - 2]);
                        } else if (index == 6) {
                          return _buildSectionHeader('Last 7 days');
                        } else {
                          return _buildChatItem(_chatHistory[index - 3]);
                        }
                      },
                    ),
                  ),

                  // Bottom section with user profile
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Settings & Preferences',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.more_horiz,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    if (index >= _itemAnimations.length) {
      return child;
    }
    return AnimatedBuilder(
      animation: _itemAnimations[index],
      builder: (context, _) {
        final value = _itemAnimations[index].value;
        return Transform.translate(
          offset: Offset(-30 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 14, top: 12, bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-40 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Icon(
                  chat['icon'] as IconData,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chat['title'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.more_horiz,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fullscreen Reel Player Screen
class _ReelPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> reel;

  const _ReelPlayerScreen({required this.reel});

  @override
  State<_ReelPlayerScreen> createState() => _ReelPlayerScreenState();
}

class _ReelPlayerScreenState extends State<_ReelPlayerScreen> {
  bool _isLiked = false;
  bool _isFollowing = false;
  bool _isPaused = false;
  bool _isLoading = true;
  VideoPlayerController? _videoController;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.reel['videoUrl'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      try {
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.play();

        // Listen to video position for progress bar
        _videoController!.addListener(_updateProgress);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateProgress() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final duration = _videoController!.value.duration.inMilliseconds;
      final position = _videoController!.value.position.inMilliseconds;
      if (duration > 0 && mounted) {
        setState(() {
          _progress = position / duration;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_updateProgress);
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
          _isPaused = true;
        } else {
          _videoController!.play();
          _isPaused = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player or Thumbnail
            if (_videoController != null &&
                _videoController!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              Image.network(
                widget.reel['thumbnail'] as String,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white54,
                        size: 80,
                      ),
                    ),
                  );
                },
              ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Pause indicator
            if (_isPaused && !_isLoading)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),

            // Top bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.reel['views'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right side actions
            Positioned(
              right: 16,
              bottom: 120,
              child: Column(
                children: [
                  // Like button
                  _buildActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: widget.reel['likes'] as String,
                    color: _isLiked ? Colors.red : Colors.white,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isLiked = !_isLiked;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Comment button
                  _buildActionButton(
                    icon: Icons.comment,
                    label: '1.2K',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showComments();
                    },
                  ),
                  const SizedBox(height: 20),
                  // Share button
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Share functionality coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // More button
                  _buildActionButton(
                    icon: Icons.more_horiz,
                    label: 'More',
                    onTap: () {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            ),

            // Bottom info
            Positioned(
              left: 16,
              right: 80,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator info
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reel['creator'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.reel['category'] as String,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isFollowing = !_isFollowing;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isFollowing ? Colors.grey[700] : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    widget.reel['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Music/Audio info
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Original Audio - ${widget.reel['creator']}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress bar at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 3,
                color: Colors.grey[800],
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress.clamp(0.0, 1.0),
                  child: Container(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '1.2K',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey, height: 1),
            // Comments list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 10,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[700],
                          child: Text(
                            'U${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@user_${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                index % 2 == 0
                                    ? 'This is amazing! 🔥🔥'
                                    : 'Great content, keep it up! 👏',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${index + 1}h ago',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.favorite_border,
                              color: Colors.grey[500],
                              size: 18,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(index + 1) * 12}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Comment input
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Add a comment...',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
