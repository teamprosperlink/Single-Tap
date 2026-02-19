import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/other providers/theme_provider.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../mixins/voice_search_mixin.dart';
import '../../models/extended_user_profile.dart';
import 'user_profile_detail_screen.dart';
import '../../services/connection_service.dart';
import '../../services/location_services/location_service.dart';

class _MosaicCardData {
  final ExtendedUserProfile? profile;
  final String userName;
  final String userId;
  final bool isDummy;
  final int dummyDataIndex;

  const _MosaicCardData({
    required this.profile,
    required this.userName,
    required this.userId,
    required this.isDummy,
    this.dummyDataIndex = 0,
  });
}

class LiveConnectTabScreen extends ConsumerStatefulWidget {
  final bool activateNearMeFilter; // Flag to activate "Near Me" filter on init
  final bool
  activateNetworkingFilter; // Flag to activate professional/networking filters on init

  const LiveConnectTabScreen({
    super.key,
    this.activateNearMeFilter = false,
    this.activateNetworkingFilter = false,
  });

  @override
  ConsumerState<LiveConnectTabScreen> createState() =>
      LiveConnectTabScreenState();
}

class LiveConnectTabScreenState extends ConsumerState<LiveConnectTabScreen>
    with SingleTickerProviderStateMixin, VoiceSearchMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionService _connectionService = ConnectionService();
  final LocationService _locationService = LocationService();

  Map<String, dynamic>? _userProfile;
  List<String> _selectedInterests = [];
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];
  List<Map<String, dynamic>> _nearbyPeople = [];
  List<Map<String, dynamic>> _filteredPeople = []; // For search results
  bool _isLoadingPeople = false;
  String _searchQuery = ''; // Search query
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Real-time location for distance calculation
  double? _currentUserLat;
  double? _currentUserLon;

  // Location caching - prevent multiple refresh attempts
  DateTime? _lastLocationRefresh;
  bool _isRefreshingLocation = false;
  static const Duration _locationCacheDuration = Duration(seconds: 90);

  // Filter options
  bool _filterByInterests = false;
  bool _filterByGender = false;
  bool _filterByConnectionTypes = false;
  bool _filterByActivities = false;
  RangeValues _distanceRange = const RangeValues(1, 500); // Distance in km
  String _locationFilter =
      'Worldwide'; // 'Near me', 'City', 'Country', 'Worldwide'
  final List<String> _selectedGenders = [];
  RangeValues _ageRange = const RangeValues(18, 60);
  bool _showOnlineOnly = false;

  // Category-specific filter selections (keyed by filter label)
  final Map<String, String?> _categoryDropdownSelections = {};

  // Pagination variables
  bool _isLoadingMore = false;
  bool _hasMoreUsers = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20; // Number of users to load per page

  // Connection status caching (to avoid repeated Firestore queries)
  final Map<String, bool> _connectionStatusCache = {}; // userId -> isConnected
  final Map<String, String?> _requestStatusCache =
      {}; // userId -> 'sent'|'received'|null
  List<String> _myConnections = []; // List of connected user IDs
  bool _connectionsLoaded = false;

  // Networking category filter
  String _selectedNetworkingCategory = 'All';
  String? _selectedSubcategory;

  static const Map<String, Map<String, dynamic>> _networkingCategoryData = {
    'Professional': {
      'icon': Icons.business_center,
      'color': Color(0xFF2196F3),
      'subs': [
        'Job Seekers',
        'Recruiters',
        'Freelancers',
        'Consultants',
        'Remote Workers',
        'Career Changers',
        'Interns',
        'Mentors',
        'Resume Review',
        'Interview Prep',
      ],
    },
    'Business': {
      'icon': Icons.storefront,
      'color': Color(0xFFFFA502),
      'subs': [
        'Startup Founders',
        'Investors',
        'Retailers',
        'Wholesalers',
        'Importers & Exporters',
        'Franchise',
        'E-commerce',
        'B2B Services',
        'Small Business',
        'Partnerships',
      ],
    },
    'Social': {
      'icon': Icons.groups,
      'color': Color(0xFF00D2D3),
      'subs': [
        'Dating',
        'Friendship',
        'Casual Hangout',
        'Party Buddies',
        'Travel Companions',
        'Roommates',
        'Pen Pals',
        'Neighbors',
        'Nightlife',
        'Coffee Meetups',
      ],
    },
    'Educational': {
      'icon': Icons.school,
      'color': Color(0xFFFF6348),
      'subs': [
        'Tutoring',
        'Study Groups',
        'Online Courses',
        'Skill Exchange',
        'Workshops',
        'Exam Prep',
        'Language Learning',
        'Research',
        'Coding Bootcamp',
        'Certifications',
      ],
    },
    'Creative': {
      'icon': Icons.palette,
      'color': Color(0xFFFF9100),
      'subs': [
        'Photography',
        'Graphic Design',
        'Music Production',
        'Film Making',
        'Writing & Blogging',
        'Animation',
        'Fashion Design',
        'Interior Design',
        'Crafts & DIY',
        'Content Creation',
      ],
    },
    'Tech': {
      'icon': Icons.computer,
      'color': Color(0xFF7C4DFF),
      'subs': [
        'Software Development',
        'Web Development',
        'Mobile Apps',
        'AI & Machine Learning',
        'Cybersecurity',
        'Cloud Computing',
        'Data Science',
        'Blockchain',
        'DevOps',
        'UI/UX Design',
      ],
    },
    'Industry': {
      'icon': Icons.factory,
      'color': Color(0xFF78909C),
      'subs': [
        'Manufacturing',
        'Construction',
        'Logistics & Supply Chain',
        'Agriculture',
        'Mining & Energy',
        'Textiles',
        'Automotive',
        'Pharmaceuticals',
        'Food Processing',
        'Real Estate',
      ],
    },
    'Investment & Finance': {
      'icon': Icons.account_balance,
      'color': Color(0xFF4CAF50),
      'subs': [
        'Stock Market',
        'Mutual Funds',
        'Real Estate Investment',
        'Cryptocurrency',
        'Insurance',
        'Banking',
        'Fintech',
        'Angel Investing',
        'Venture Capital',
        'Financial Planning',
      ],
    },
    'Event & Meetup': {
      'icon': Icons.event,
      'color': Color(0xFFE040FB),
      'subs': [
        'Conferences',
        'Workshops & Seminars',
        'Hackathons',
        'Networking Events',
        'Cultural Events',
        'Sports Events',
        'Concerts & Music',
        'Webinars',
        'Trade Shows',
        'Community Gatherings',
      ],
    },
    'Community': {
      'icon': Icons.volunteer_activism,
      'color': Color(0xFFFF6B81),
      'subs': [
        'NGO & Nonprofits',
        'Volunteering',
        'Social Causes',
        'Environmental',
        'Health Awareness',
        'Education Outreach',
        'Animal Welfare',
        'Elder Care',
        'Women Empowerment',
        'Youth Development',
      ],
    },
    'Personal Development': {
      'icon': Icons.self_improvement,
      'color': Color(0xFF00E676),
      'subs': [
        'Fitness & Gym',
        'Meditation & Yoga',
        'Public Speaking',
        'Leadership Skills',
        'Time Management',
        'Emotional Intelligence',
        'Goal Setting',
        'Mindfulness',
        'Life Coaching',
        'Book Club',
      ],
    },
    'Global / NRI': {
      'icon': Icons.public,
      'color': Color(0xFF1E90FF),
      'subs': [
        'Immigration',
        'Visa Assistance',
        'Cultural Exchange',
        'Overseas Jobs',
        'Study Abroad',
        'Diaspora Connect',
        'International Trade',
        'Relocation Help',
        'Foreign Investment',
        'NRI Services',
      ],
    },
  };

  // Category → relevant connection type groups & activity groups
  static const Map<String, List<String>> _categoryConnectionGroups = {
    'Professional': [], // covered by Employment Type, Work Mode
    'Business': [], // covered by Business Model, Business Stage
    'Social': ['Social', 'Other'],
    'Educational': ['Educational'],
    'Creative': ['Creative'],
    'Tech': [], // covered by Purpose, Tech Stack
    'Industry': [], // covered by Business Role, Trade Type
    'Investment & Finance': [], // covered by Purpose, Risk Appetite
    'Event & Meetup': [], // covered by Event Format, When
    'Community': ['Community'], // only Community group (not Social)
    'Personal Development': [], // covered by Format, Goal
    'Global / NRI': [], // covered by Service Type, Urgency
  };

  static const Map<String, List<String>> _categoryActivityGroups = {
    'Professional': [],
    'Business': [],
    'Social': ['Sports', 'Fitness', 'Outdoor', 'Creative'],
    'Educational': ['Creative'],
    'Creative': ['Creative'],
    'Tech': [],
    'Industry': [],
    'Investment & Finance': [],
    'Event & Meetup': ['Sports', 'Creative'],
    'Community': ['Sports', 'Outdoor'],
    'Personal Development': ['Fitness', 'Outdoor'],
    'Global / NRI': [],
  };

  // ── Category-specific filters (shown below category/subcategory) ──
  static const Map<String, List<Map<String, dynamic>>> _categoryFilters = {
    'Professional': [
      {
        'label': 'Experience Level',
        'type': 'dropdown',
        'options': [
          'Entry Level',
          'Mid Level',
          'Senior',
          'Executive',
          'Intern',
        ],
      },
      {
        'label': 'Employment Type',
        'type': 'dropdown',
        'options': [
          'Full-Time',
          'Part-Time',
          'Contract',
          'Freelance',
          'Internship',
        ],
      },
      {
        'label': 'Work Mode',
        'type': 'dropdown',
        'options': ['On-Site', 'Remote', 'Hybrid'],
      },
      {
        'label': 'Industry',
        'type': 'dropdown',
        'options': [
          'Technology',
          'Healthcare',
          'Finance',
          'Education',
          'Marketing',
          'Legal',
          'Manufacturing',
          'Retail',
          'Media',
          'Government',
          'Other',
        ],
      },
    ],
    'Business': [
      {
        'label': 'Business Stage',
        'type': 'dropdown',
        'options': [
          'Idea Stage',
          'Pre-Revenue',
          'Early Revenue',
          'Growth Stage',
          'Established',
          'Scaling',
        ],
      },
      {
        'label': 'Company Size',
        'type': 'dropdown',
        'options': ['Solo', '2-10', '11-50', '51-200', '201-1000', '1000+'],
      },
      {
        'label': 'Business Model',
        'type': 'dropdown',
        'options': ['B2B', 'B2C', 'D2C', 'Marketplace', 'SaaS', 'Subscription'],
      },
      {
        'label': 'Industry Sector',
        'type': 'dropdown',
        'options': [
          'Technology',
          'Retail',
          'F&B',
          'Healthcare',
          'Manufacturing',
          'Real Estate',
          'Agriculture',
          'Services',
          'Logistics',
          'Finance',
          'Other',
        ],
      },
    ],
    'Social': [
      {
        'label': 'Availability',
        'type': 'dropdown',
        'options': ['Now', 'Today', 'This Week', 'This Weekend', 'Flexible'],
      },
      {
        'label': 'Interests',
        'type': 'dropdown',
        'options': [
          'Music',
          'Sports',
          'Travel',
          'Food',
          'Art',
          'Tech',
          'Fitness',
          'Reading',
          'Gaming',
          'Movies',
          'Photography',
          'Cooking',
        ],
      },
      {
        'label': 'Vibe',
        'type': 'dropdown',
        'options': [
          'Chill',
          'Energetic',
          'Intellectual',
          'Creative',
          'Adventurous',
        ],
      },
    ],
    'Educational': [
      {
        'label': 'Skill Level',
        'type': 'dropdown',
        'options': ['Beginner', 'Intermediate', 'Advanced', 'Expert'],
      },
      {
        'label': 'Format',
        'type': 'dropdown',
        'options': ['In-Person', 'Online Live', 'Self-Paced', 'Hybrid'],
      },
      {
        'label': 'Subject',
        'type': 'dropdown',
        'options': [
          'Mathematics',
          'Science',
          'Languages',
          'Programming',
          'Business',
          'Arts',
          'Music',
          'Test Prep',
          'Other',
        ],
      },
      {
        'label': 'Language',
        'type': 'dropdown',
        'options': [
          'English',
          'Hindi',
          'Spanish',
          'French',
          'Mandarin',
          'Arabic',
          'German',
          'Japanese',
          'Other',
        ],
      },
    ],
    'Creative': [
      {
        'label': 'Skill Level',
        'type': 'dropdown',
        'options': [
          'Hobbyist',
          'Beginner',
          'Intermediate',
          'Professional',
          'Expert',
        ],
      },
      {
        'label': 'Collaboration',
        'type': 'dropdown',
        'options': [
          'Hire Me',
          'Looking to Hire',
          'Collaborate',
          'Learn Together',
          'Mentor/Mentee',
        ],
      },
      {
        'label': 'Portfolio',
        'type': 'dropdown',
        'options': ['Has Portfolio', 'No Portfolio'],
      },
    ],
    'Tech': [
      {
        'label': 'Experience Level',
        'type': 'dropdown',
        'options': [
          'Junior (0-2 yr)',
          'Mid (2-5 yr)',
          'Senior (5-10 yr)',
          'Lead/Architect (10+ yr)',
        ],
      },
      {
        'label': 'Tech Stack',
        'type': 'dropdown',
        'options': [
          'Python',
          'JavaScript',
          'TypeScript',
          'Java',
          'C++',
          'Go',
          'Rust',
          'Swift',
          'Kotlin',
          'Dart',
          'Flutter',
          'React',
        ],
      },
      {
        'label': 'Purpose',
        'type': 'dropdown',
        'options': [
          'Hire',
          'Get Hired',
          'Collaborate',
          'Learn',
          'Mentor',
          'Open Source',
        ],
      },
    ],
    'Industry': [
      {
        'label': 'Business Role',
        'type': 'dropdown',
        'options': [
          'Manufacturer',
          'Supplier',
          'Distributor',
          'Buyer',
          'Consultant',
          'Service Provider',
        ],
      },
      {
        'label': 'Company Size',
        'type': 'dropdown',
        'options': [
          'Micro (1-10)',
          'Small (11-50)',
          'Medium (51-200)',
          'Large (201-1000)',
          'Enterprise (1000+)',
        ],
      },
      {
        'label': 'Trade Type',
        'type': 'dropdown',
        'options': ['Local', 'National', 'International'],
      },
      {
        'label': 'Certifications',
        'type': 'dropdown',
        'options': [
          'ISO 9001',
          'ISO 14001',
          'GMP',
          'HACCP',
          'CE',
          'FDA',
          'BIS',
          'Organic',
        ],
      },
    ],
    'Investment & Finance': [
      {
        'label': 'Experience',
        'type': 'dropdown',
        'options': ['Beginner', 'Intermediate', 'Advanced', 'Professional'],
      },
      {
        'label': 'Risk Appetite',
        'type': 'dropdown',
        'options': [
          'Conservative',
          'Moderate',
          'Aggressive',
          'Very Aggressive',
        ],
      },
      {
        'label': 'Investment Horizon',
        'type': 'dropdown',
        'options': [
          'Short-Term (< 1yr)',
          'Medium (1-3yr)',
          'Long-Term (3-10yr)',
          'Very Long (10+yr)',
        ],
      },
      {
        'label': 'Purpose',
        'type': 'dropdown',
        'options': ['Invest', 'Raise Capital', 'Advise', 'Learn', 'Partner'],
      },
    ],
    'Event & Meetup': [
      {
        'label': 'Event Format',
        'type': 'dropdown',
        'options': ['In-Person', 'Online', 'Hybrid'],
      },
      {
        'label': 'When',
        'type': 'dropdown',
        'options': ['Today', 'This Week', 'This Weekend', 'This Month'],
      },
      {
        'label': 'Time of Day',
        'type': 'dropdown',
        'options': ['Morning', 'Afternoon', 'Evening', 'Night'],
      },
      {
        'label': 'Price',
        'type': 'dropdown',
        'options': ['Free', 'Paid'],
      },
    ],
    'Community': [
      {
        'label': 'Involvement',
        'type': 'dropdown',
        'options': ['Volunteer', 'Donate', 'Organize', 'Advocate', 'Mentor'],
      },
      {
        'label': 'Commitment',
        'type': 'dropdown',
        'options': ['One-Time', 'Weekly', 'Monthly', 'Ongoing', 'Seasonal'],
      },
      {
        'label': 'Cause Area',
        'type': 'dropdown',
        'options': [
          'Education',
          'Health',
          'Environment',
          'Poverty',
          'Human Rights',
          'Animals',
          'Arts & Culture',
          'Technology',
        ],
      },
      {
        'label': 'Skills Offered',
        'type': 'dropdown',
        'options': [
          'Teaching',
          'Medical',
          'Technical',
          'Legal',
          'Marketing',
          'Fundraising',
          'Counseling',
          'Creative',
        ],
      },
    ],
    'Personal Development': [
      {
        'label': 'Level',
        'type': 'dropdown',
        'options': ['Beginner', 'Intermediate', 'Advanced'],
      },
      {
        'label': 'Format',
        'type': 'dropdown',
        'options': [
          'In-Person',
          'Online Live',
          'Self-Paced',
          'Group',
          '1-on-1',
        ],
      },
      {
        'label': 'Session Duration',
        'type': 'dropdown',
        'options': ['15 min', '30 min', '45 min', '1 hr', '2 hr'],
      },
      {
        'label': 'Goal',
        'type': 'dropdown',
        'options': [
          'Weight Loss',
          'Muscle Gain',
          'Flexibility',
          'Stress Relief',
          'Focus',
          'Confidence',
          'Leadership',
        ],
      },
    ],
    'Global / NRI': [
      {
        'label': 'Destination',
        'type': 'dropdown',
        'options': [
          'USA',
          'Canada',
          'UK',
          'Australia',
          'Germany',
          'UAE',
          'Singapore',
          'New Zealand',
          'Other',
        ],
      },
      {
        'label': 'Service Type',
        'type': 'dropdown',
        'options': [
          'Consultation',
          'Documentation',
          'Representation',
          'Guidance',
          'Community',
        ],
      },
      {
        'label': 'Urgency',
        'type': 'dropdown',
        'options': [
          'Immediate',
          'Within 1 Month',
          'Within 3 Months',
          'Within 6 Months',
          'Planning Ahead',
        ],
      },
      {
        'label': 'Language',
        'type': 'dropdown',
        'options': [
          'English',
          'Hindi',
          'Gujarati',
          'Punjabi',
          'Tamil',
          'Telugu',
          'Bengali',
          'Marathi',
        ],
      },
    ],
  };

  // ── Subcategory-specific additional filters ──
  static const Map<String, List<Map<String, dynamic>>> _subcategoryFilters = {
    // Professional subcategories
    'Job Seekers': [
      {
        'label': 'Education',
        'type': 'dropdown',
        'options': [
          'High School',
          'Associate',
          "Bachelor's",
          "Master's",
          'PhD',
          'Self-Taught',
        ],
      },
    ],
    'Freelancers': [
      {
        'label': 'Project Type',
        'type': 'dropdown',
        'options': ['Hourly', 'Fixed-Price', 'Retainer', 'Equity'],
      },
    ],
    'Consultants': [
      {
        'label': 'Specialty',
        'type': 'dropdown',
        'options': [
          'Strategy',
          'Operations',
          'Finance',
          'Marketing',
          'HR',
          'IT',
          'Legal',
          'Other',
        ],
      },
    ],
    'Remote Workers': [
      {
        'label': 'Time Zone',
        'type': 'dropdown',
        'options': [
          'IST (UTC+5:30)',
          'EST (UTC-5)',
          'PST (UTC-8)',
          'GMT (UTC+0)',
          'CET (UTC+1)',
          'AEST (UTC+10)',
          'JST (UTC+9)',
        ],
      },
    ],
    'Recruiters': [
      {
        'label': 'Hiring For',
        'type': 'dropdown',
        'options': [
          'Tech',
          'Sales',
          'Marketing',
          'Design',
          'Operations',
          'Finance',
          'HR',
          'Executive',
        ],
      },
    ],
    // Business subcategories
    'Startup Founders': [
      {
        'label': 'Funding Stage',
        'type': 'dropdown',
        'options': [
          'Bootstrapped',
          'Pre-Seed',
          'Seed',
          'Series A',
          'Series B',
          'Series C+',
        ],
      },
    ],
    'Investors': [
      {
        'label': 'Investment Type',
        'type': 'dropdown',
        'options': ['Angel', 'VC', 'PE', 'Debt', 'Crypto'],
      },
      {
        'label': 'Preferred Stage',
        'type': 'dropdown',
        'options': [
          'Pre-Seed',
          'Seed',
          'Series A',
          'Series B',
          'Series C+',
          'Growth',
        ],
      },
    ],
    'E-commerce': [
      {
        'label': 'Platform',
        'type': 'dropdown',
        'options': [
          'Shopify',
          'Amazon',
          'WooCommerce',
          'Custom',
          'Multi-Platform',
        ],
      },
    ],
    'Franchise': [
      {
        'label': 'Franchise Type',
        'type': 'dropdown',
        'options': ['Food', 'Retail', 'Service', 'Education', 'Fitness'],
      },
    ],
    // Social subcategories
    'Dating': [
      {
        'label': 'Relationship Goal',
        'type': 'dropdown',
        'options': ['Serious', 'Casual', 'Open to Anything'],
      },
      {
        'label': 'Lifestyle',
        'type': 'dropdown',
        'options': [
          'Non-Smoker',
          'Social Drinker',
          'Vegetarian',
          'Fitness Lover',
          'Pet Lover',
        ],
      },
    ],
    'Travel Companions': [
      {
        'label': 'Travel Style',
        'type': 'dropdown',
        'options': ['Budget', 'Mid-Range', 'Luxury', 'Backpacking'],
      },
      {
        'label': 'Trip Duration',
        'type': 'dropdown',
        'options': ['Weekend', '1 Week', '2+ Weeks', 'Long-Term'],
      },
    ],
    'Roommates': [
      {
        'label': 'Lifestyle',
        'type': 'dropdown',
        'options': [
          'Early Bird',
          'Night Owl',
          'Pet-Friendly',
          'Vegetarian',
          'Non-Smoker',
          'Quiet',
        ],
      },
    ],
    'Party Buddies': [
      {
        'label': 'Scene',
        'type': 'dropdown',
        'options': ['Clubs', 'Bars', 'House Parties', 'Live Music', 'Rooftops'],
      },
      {
        'label': 'Music Taste',
        'type': 'dropdown',
        'options': ['EDM', 'Hip-Hop', 'Bollywood', 'Rock', 'Pop', 'Jazz'],
      },
    ],
    // Educational subcategories
    'Exam Prep': [
      {
        'label': 'Exam Type',
        'type': 'dropdown',
        'options': [
          'SAT',
          'GRE',
          'GMAT',
          'IELTS',
          'TOEFL',
          'UPSC',
          'CAT',
          'JEE',
          'NEET',
          'Other',
        ],
      },
    ],
    'Language Learning': [
      {
        'label': 'Target Language',
        'type': 'dropdown',
        'options': [
          'English',
          'Spanish',
          'French',
          'German',
          'Mandarin',
          'Japanese',
          'Korean',
          'Arabic',
          'Hindi',
          'Other',
        ],
      },
      {
        'label': 'Proficiency',
        'type': 'dropdown',
        'options': [
          'A1 (Beginner)',
          'A2 (Elementary)',
          'B1 (Intermediate)',
          'B2 (Upper Intermediate)',
          'C1 (Advanced)',
          'C2 (Fluent)',
        ],
      },
    ],
    'Coding Bootcamp': [
      {
        'label': 'Tech Stack',
        'type': 'dropdown',
        'options': [
          'Python',
          'JavaScript',
          'React',
          'Node.js',
          'Flutter',
          'AI/ML',
          'Java',
          'Swift',
        ],
      },
      {
        'label': 'Duration',
        'type': 'dropdown',
        'options': ['4 Weeks', '8 Weeks', '12 Weeks', '6 Months'],
      },
    ],
    'Study Groups': [
      {
        'label': 'Group Size',
        'type': 'dropdown',
        'options': ['2-3', '4-6', '7-10', '10+'],
      },
    ],
    // Creative subcategories
    'Photography': [
      {
        'label': 'Style',
        'type': 'dropdown',
        'options': [
          'Portrait',
          'Landscape',
          'Wedding',
          'Product',
          'Street',
          'Fashion',
          'Food',
          'Drone',
        ],
      },
    ],
    'Graphic Design': [
      {
        'label': 'Specialty',
        'type': 'dropdown',
        'options': [
          'Logo',
          'Branding',
          'UI/UX',
          'Print',
          'Packaging',
          'Social Media',
          'Illustration',
        ],
      },
    ],
    'Music Production': [
      {
        'label': 'Genre',
        'type': 'dropdown',
        'options': [
          'Pop',
          'Hip-Hop',
          'EDM',
          'Classical',
          'Rock',
          'Bollywood',
          'Jazz',
          'Lo-Fi',
        ],
      },
      {
        'label': 'Service',
        'type': 'dropdown',
        'options': [
          'Mixing',
          'Mastering',
          'Beat Making',
          'Composition',
          'Sound Design',
        ],
      },
    ],
    'Film Making': [
      {
        'label': 'Type',
        'type': 'dropdown',
        'options': [
          'Short Film',
          'Documentary',
          'Commercial',
          'Music Video',
          'Corporate',
          'Wedding',
        ],
      },
      {
        'label': 'Role Needed',
        'type': 'dropdown',
        'options': [
          'Director',
          'Editor',
          'Cinematographer',
          'Actor',
          'Sound',
          'VFX',
        ],
      },
    ],
    'Content Creation': [
      {
        'label': 'Platform',
        'type': 'dropdown',
        'options': [
          'YouTube',
          'Instagram',
          'TikTok',
          'Podcast',
          'Blog',
          'LinkedIn',
        ],
      },
      {
        'label': 'Content Type',
        'type': 'dropdown',
        'options': ['Video', 'Photo', 'Written', 'Audio', 'Mixed Media'],
      },
    ],
    'Writing & Blogging': [
      {
        'label': 'Niche',
        'type': 'dropdown',
        'options': [
          'Tech',
          'Lifestyle',
          'Travel',
          'Finance',
          'Health',
          'Food',
          'Fiction',
          'Copywriting',
        ],
      },
    ],
    // Tech subcategories
    'Software Development': [
      {
        'label': 'Domain',
        'type': 'dropdown',
        'options': ['Backend', 'Frontend', 'Full-Stack', 'Embedded', 'Systems'],
      },
    ],
    'Mobile Apps': [
      {
        'label': 'Platform',
        'type': 'dropdown',
        'options': [
          'iOS',
          'Android',
          'Cross-Platform',
          'Flutter',
          'React Native',
        ],
      },
    ],
    'AI & Machine Learning': [
      {
        'label': 'Subfield',
        'type': 'dropdown',
        'options': [
          'NLP',
          'Computer Vision',
          'Deep Learning',
          'Generative AI',
          'MLOps',
          'Reinforcement Learning',
        ],
      },
    ],
    'Cybersecurity': [
      {
        'label': 'Focus',
        'type': 'dropdown',
        'options': [
          'Pen Testing',
          'Security Audit',
          'Compliance',
          'Incident Response',
          'SOC',
          'GRC',
        ],
      },
    ],
    'Cloud Computing': [
      {
        'label': 'Cloud Platform',
        'type': 'dropdown',
        'options': ['AWS', 'Azure', 'GCP', 'Multi-Cloud'],
      },
    ],
    'Data Science': [
      {
        'label': 'Tools',
        'type': 'dropdown',
        'options': ['Python', 'R', 'SQL', 'Tableau', 'Power BI', 'Spark'],
      },
    ],
    'Blockchain': [
      {
        'label': 'Chain',
        'type': 'dropdown',
        'options': ['Ethereum', 'Solana', 'Bitcoin', 'Polygon', 'Polkadot'],
      },
      {
        'label': 'Focus',
        'type': 'dropdown',
        'options': ['Smart Contracts', 'DeFi', 'NFT', 'DApp', 'Web3'],
      },
    ],
    'UI/UX Design': [
      {
        'label': 'Tools',
        'type': 'dropdown',
        'options': ['Figma', 'Sketch', 'Adobe XD', 'Framer', 'InVision'],
      },
    ],
    // Industry subcategories
    'Manufacturing': [
      {
        'label': 'Capacity',
        'type': 'dropdown',
        'options': ['Small Batch', 'Medium', 'Large Scale', 'Mass Production'],
      },
    ],
    'Construction': [
      {
        'label': 'Project Type',
        'type': 'dropdown',
        'options': [
          'Residential',
          'Commercial',
          'Infrastructure',
          'Industrial',
          'Renovation',
        ],
      },
    ],
    'Real Estate': [
      {
        'label': 'Property Type',
        'type': 'dropdown',
        'options': [
          'Residential',
          'Commercial',
          'Industrial',
          'Land',
          'Co-Working',
        ],
      },
      {
        'label': 'Transaction',
        'type': 'dropdown',
        'options': ['Buy', 'Sell', 'Rent', 'Lease'],
      },
    ],
    'Agriculture': [
      {
        'label': 'Product',
        'type': 'dropdown',
        'options': [
          'Crops',
          'Livestock',
          'Dairy',
          'Poultry',
          'Aquaculture',
          'Organic',
          'AgriTech',
        ],
      },
    ],
    'Automotive': [
      {
        'label': 'Segment',
        'type': 'dropdown',
        'options': [
          'Passenger',
          'Commercial',
          'Two-Wheeler',
          'EV',
          'Parts',
          'Service',
        ],
      },
    ],
    'Pharmaceuticals': [
      {
        'label': 'Type',
        'type': 'dropdown',
        'options': ['Generic', 'Branded', 'API', 'Biotech', 'Medical Devices'],
      },
    ],
    'Food Processing': [
      {
        'label': 'Category',
        'type': 'dropdown',
        'options': [
          'Dairy',
          'Bakery',
          'Beverages',
          'Frozen',
          'Snacks',
          'Spices',
          'Organic',
        ],
      },
    ],
    // Investment & Finance subcategories
    'Stock Market': [
      {
        'label': 'Sector',
        'type': 'dropdown',
        'options': [
          'Technology',
          'Healthcare',
          'Finance',
          'Energy',
          'Consumer',
          'Industrial',
          'Real Estate',
        ],
      },
      {
        'label': 'Market Cap',
        'type': 'dropdown',
        'options': ['Micro', 'Small', 'Mid', 'Large', 'Mega'],
      },
    ],
    'Cryptocurrency': [
      {
        'label': 'Token Type',
        'type': 'dropdown',
        'options': ['Layer 1', 'Layer 2', 'DeFi', 'NFT', 'Stablecoin', 'Meme'],
      },
    ],
    'Mutual Funds': [
      {
        'label': 'Fund Type',
        'type': 'dropdown',
        'options': ['Equity', 'Debt', 'Hybrid', 'Index', 'ELSS', 'Liquid'],
      },
    ],
    'Angel Investing': [
      {
        'label': 'Preferred Sector',
        'type': 'dropdown',
        'options': [
          'Tech',
          'Healthcare',
          'FinTech',
          'EdTech',
          'D2C',
          'SaaS',
          'AgriTech',
        ],
      },
    ],
    'Venture Capital': [
      {
        'label': 'Preferred Stage',
        'type': 'dropdown',
        'options': ['Pre-Seed', 'Seed', 'Series A', 'Series B', 'Series C+'],
      },
    ],
    'Financial Planning': [
      {
        'label': 'Goal',
        'type': 'dropdown',
        'options': [
          'Retirement',
          'Education',
          'Wealth Building',
          'Tax Saving',
          'Emergency Fund',
          'Debt Payoff',
        ],
      },
    ],
    // Event & Meetup subcategories
    'Hackathons': [
      {
        'label': 'Theme',
        'type': 'dropdown',
        'options': [
          'AI',
          'Web3',
          'FinTech',
          'HealthTech',
          'Social Good',
          'Open',
        ],
      },
      {
        'label': 'Team Size',
        'type': 'dropdown',
        'options': ['Solo', '2-3', '4-5', 'Open'],
      },
    ],
    'Conferences': [
      {
        'label': 'Audience',
        'type': 'dropdown',
        'options': ['Beginner', 'Professional', 'Executive', 'Academic'],
      },
    ],
    'Sports Events': [
      {
        'label': 'Sport',
        'type': 'dropdown',
        'options': [
          'Cricket',
          'Football',
          'Tennis',
          'Running',
          'Cycling',
          'Swimming',
          'Martial Arts',
          'Other',
        ],
      },
      {
        'label': 'Participation',
        'type': 'dropdown',
        'options': ['Participate', 'Spectate', 'Volunteer'],
      },
    ],
    'Concerts & Music': [
      {
        'label': 'Genre',
        'type': 'dropdown',
        'options': [
          'Pop',
          'Rock',
          'Classical',
          'EDM',
          'Hip-Hop',
          'Bollywood',
          'Jazz',
          'Indie',
        ],
      },
    ],
    // Community subcategories
    'Volunteering': [
      {
        'label': 'Availability',
        'type': 'dropdown',
        'options': ['Weekdays', 'Weekends', 'Evenings', 'Flexible'],
      },
    ],
    'Environmental': [
      {
        'label': 'Focus',
        'type': 'dropdown',
        'options': [
          'Climate',
          'Conservation',
          'Recycling',
          'Clean Energy',
          'Water',
          'Reforestation',
          'Wildlife',
        ],
      },
    ],
    'Animal Welfare': [
      {
        'label': 'Animal Type',
        'type': 'dropdown',
        'options': [
          'Dogs',
          'Cats',
          'Farm Animals',
          'Wildlife',
          'Marine',
          'Birds',
          'All',
        ],
      },
    ],
    'Women Empowerment': [
      {
        'label': 'Focus',
        'type': 'dropdown',
        'options': [
          'Education',
          'Employment',
          'Safety',
          'Health',
          'Legal Rights',
          'Leadership',
          'Financial',
        ],
      },
    ],
    'Youth Development': [
      {
        'label': 'Age Group',
        'type': 'dropdown',
        'options': ['6-10', '11-14', '15-18', '18-25'],
      },
      {
        'label': 'Program Type',
        'type': 'dropdown',
        'options': [
          'Sports',
          'STEM',
          'Arts',
          'Leadership',
          'Career',
          'Life Skills',
        ],
      },
    ],
    // Personal Development subcategories
    'Fitness & Gym': [
      {
        'label': 'Workout Type',
        'type': 'dropdown',
        'options': [
          'Strength',
          'Cardio',
          'CrossFit',
          'HIIT',
          'Calisthenics',
          'Functional',
        ],
      },
      {
        'label': 'Fitness Goal',
        'type': 'dropdown',
        'options': [
          'Weight Loss',
          'Muscle Gain',
          'Endurance',
          'Flexibility',
          'General Fitness',
        ],
      },
    ],
    'Meditation & Yoga': [
      {
        'label': 'Style',
        'type': 'dropdown',
        'options': [
          'Hatha',
          'Vinyasa',
          'Ashtanga',
          'Kundalini',
          'Guided Meditation',
          'Breathwork',
        ],
      },
    ],
    'Public Speaking': [
      {
        'label': 'Context',
        'type': 'dropdown',
        'options': [
          'Professional',
          'TED-Style',
          'Debate',
          'Toastmasters',
          'Storytelling',
          'Sales',
        ],
      },
    ],
    'Life Coaching': [
      {
        'label': 'Specialty',
        'type': 'dropdown',
        'options': [
          'Career',
          'Relationships',
          'Health',
          'Finance',
          'Confidence',
          'Executive',
        ],
      },
    ],
    'Book Club': [
      {
        'label': 'Genre',
        'type': 'dropdown',
        'options': [
          'Self-Help',
          'Business',
          'Fiction',
          'Science',
          'Philosophy',
          'Biography',
          'Psychology',
        ],
      },
      {
        'label': 'Pace',
        'type': 'dropdown',
        'options': ['1 Chapter/Week', 'Whole Book', 'Audio + Discussion'],
      },
    ],
    // Global / NRI subcategories
    'Immigration': [
      {
        'label': 'Visa Category',
        'type': 'dropdown',
        'options': [
          'Work Visa',
          'Family Visa',
          'Investor Visa',
          'Permanent Residence',
          'Citizenship',
          'Asylum',
        ],
      },
    ],
    'Study Abroad': [
      {
        'label': 'Degree Level',
        'type': 'dropdown',
        'options': [
          'Undergraduate',
          'Postgraduate',
          'PhD',
          'Diploma',
          'Certificate',
          'Short Course',
        ],
      },
      {
        'label': 'Intake',
        'type': 'dropdown',
        'options': ['Fall', 'Spring', 'Summer', 'Rolling'],
      },
    ],
    'Overseas Jobs': [
      {
        'label': 'Contract Type',
        'type': 'dropdown',
        'options': [
          'Permanent',
          'Contract',
          'Temporary',
          'Sponsorship Available',
        ],
      },
    ],
    'International Trade': [
      {
        'label': 'Direction',
        'type': 'dropdown',
        'options': ['Import', 'Export', 'Both'],
      },
      {
        'label': 'Volume',
        'type': 'dropdown',
        'options': ['Small', 'Medium', 'Large', 'Bulk'],
      },
    ],
    'Relocation Help': [
      {
        'label': 'Service Needed',
        'type': 'dropdown',
        'options': [
          'Housing',
          'Banking',
          'Schools',
          'Healthcare',
          'Legal',
          'Moving',
        ],
      },
    ],
    'NRI Services': [
      {
        'label': 'Service',
        'type': 'dropdown',
        'options': [
          'Tax Filing',
          'Property Management',
          'Power of Attorney',
          'Bank Account',
          'Insurance',
          'Repatriation',
        ],
      },
    ],
  };

  // Available connection types (grouped)
  final Map<String, List<String>> _connectionTypeGroups = {
    'Social': [
      'Dating',
      'Friendship',
      'Casual Hangout',
      'Travel Buddy',
      'Nightlife Partner',
    ],
    'Professional': [
      'Networking',
      'Mentorship',
      'Business Partner',
      'Career Advice',
      'Freelancing',
    ],
    'Educational': [
      'Study Group',
      'Tutoring',
      'Language Exchange',
      'Skill Sharing',
      'Exam Prep',
    ],
    'Creative': [
      'Music Jam',
      'Art Collaboration',
      'Photography',
      'Content Creation',
      'Film Making',
    ],
    'Community': [
      'Volunteering',
      'Social Causes',
      'Environmental',
      'Community Service',
      'Youth Development',
    ],
    'Other': [
      'Roommate',
      'Pet Playdate',
      'Gaming',
      'Online Friends',
      'Event Companion',
    ],
  };

  // Available activities (grouped)
  final Map<String, List<String>> _activityGroups = {
    'Sports': [
      'Tennis',
      'Badminton',
      'Basketball',
      'Football',
      'Volleyball',
      'Golf',
      'Table Tennis',
      'Squash',
    ],
    'Fitness': [
      'Running',
      'Gym',
      'Yoga',
      'Pilates',
      'CrossFit',
      'Cycling',
      'Swimming',
      'Dance',
    ],
    'Outdoor': [
      'Hiking',
      'Rock Climbing',
      'Camping',
      'Kayaking',
      'Surfing',
      'Mountain Biking',
      'Trail Running',
    ],
    'Creative': [
      'Photography',
      'Painting',
      'Music',
      'Writing',
      'Cooking',
      'Crafts',
      'Gaming',
    ],
  };

  // Expanded state for each group
  final Map<String, bool> _expandedConnectionGroups = {};
  final Map<String, bool> _expandedActivityGroups = {};

  // Common interests for users to choose from
  final List<String> _availableInterests = [
    'Dating',
    'Friendship',
    'Business',
    'Roommate',
    'Job Seeker',
    'Hiring',
    'Selling',
    'Buying',
    'Lost & Found',
    'Events',
    'Sports',
    'Travel',
    'Food',
    'Music',
    'Movies',
    'Gaming',
    'Fitness',
    'Art',
    'Technology',
    'Photography',
    'Fashion',
  ];

  // Tab categories for TabBar
  final List<String> _tabCategories = ['Discover Connect', 'Smart Connect'];

  @override
  void initState() {
    super.initState();

    // Initialize speech from VoiceSearchMixin
    initSpeech();

    // Initialize TabController
    _tabController = TabController(length: _tabCategories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
        final selectedCategory = _tabCategories[_tabController.index];
        setState(() {
          if (selectedCategory == 'Discover Connect') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Worldwide';
          } else if (selectedCategory == 'Smart Connect') {
            _filterByInterests = false;
            _selectedInterests.clear();
            _locationFilter = 'Smart Connect';
          } else {
            _filterByInterests = true;
            _locationFilter = 'Smart Connect';
            _selectedInterests.removeWhere(
              (item) =>
                  ['Dating', 'Friendship', 'Business', 'Sports'].contains(item),
            );
            _selectedInterests.add(selectedCategory);
          }
        });
        _loadNearbyPeople();
      }
    });

    // Activate "Near Me" filter if requested
    if (widget.activateNearMeFilter) {
      _locationFilter = 'Near me';
    }

    // No pre-loaded filters — filters only activate when user applies them

    // Initialize expanded state for all groups (all collapsed by default)
    for (var groupName in _connectionTypeGroups.keys) {
      _expandedConnectionGroups[groupName] = false;
    }
    for (var groupName in _activityGroups.keys) {
      _expandedActivityGroups[groupName] = false;
    }
    _loadMyConnections(); // Load connections for caching
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    disposeVoiceSearch(); // From VoiceSearchMixin
    super.dispose();
  }

  /// Load user's connections list once for caching
  Future<void> _loadMyConnections() async {
    if (_connectionsLoaded) return; // Already loaded

    try {
      _myConnections = await _connectionService.getUserConnections();
      _connectionsLoaded = true;

      // Initialize connection status cache
      for (var userId in _myConnections) {
        _connectionStatusCache[userId] = true;
      }

      debugPrint(
        'LiveConnect: Loaded ${_myConnections.length} connections for caching',
      );
    } catch (e) {
      debugPrint('LiveConnect: Error loading connections: $e');
    }
  }

  /// Update connection status cache when connection status changes
  void updateConnectionCache(
    String userId,
    bool isConnected, {
    String? requestStatus,
  }) {
    setState(() {
      _connectionStatusCache[userId] = isConnected;
      if (isConnected) {
        if (!_myConnections.contains(userId)) {
          _myConnections.add(userId);
        }
      } else {
        _myConnections.remove(userId);
      }
      if (requestStatus != null) {
        _requestStatusCache[userId] = requestStatus;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Load user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        setState(() {
          _userProfile = userData;
          // Load user's saved interests
          _selectedInterests = List<String>.from(userData?['interests'] ?? []);
        });

        // Always load nearby people (filters can be applied via filter dialog)
        _loadNearbyPeople();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load profile. Please check your connection and try again.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadUserProfile();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadNearbyPeople({
    bool loadMore = false,
    bool forceRefreshLocation = false,
  }) async {
    if (!mounted) return;

    // If interest filter is on but no interests selected, return early
    if (_filterByInterests && _selectedInterests.isEmpty) return;

    // If already loading more or no more users, return
    if (loadMore && (_isLoadingMore || !_hasMoreUsers)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoadingPeople = true;
        // Reset pagination state for initial load
        _lastDocument = null;
        _hasMoreUsers = true;
      }
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userCity = _userProfile?['city'];

      // Check if we need to refresh location (cached for 90 seconds)
      final now = DateTime.now();
      final shouldRefreshLocation =
          forceRefreshLocation ||
          _currentUserLat == null ||
          _currentUserLon == null ||
          _lastLocationRefresh == null ||
          now.difference(_lastLocationRefresh!) > _locationCacheDuration;

      if (shouldRefreshLocation && !_isRefreshingLocation) {
        if (mounted) {
          setState(() {
            _isRefreshingLocation = true;
          });
        }
        debugPrint(
          'LiveConnect: Refreshing location (cache expired or forced)...',
        );

        final position = await _locationService.getCurrentLocation(
          silent: true,
        );

        if (position != null && mounted) {
          setState(() {
            _currentUserLat = position.latitude;
            _currentUserLon = position.longitude;
            _lastLocationRefresh = now;
            _isRefreshingLocation = false;
          });
          debugPrint(
            'LiveConnect: Location refreshed: ${position.latitude}, ${position.longitude}',
          );
        } else {
          if (_currentUserLat == null || _currentUserLon == null) {
            // Fall back to profile location only if we have no cached location
            _currentUserLat = _userProfile?['latitude']?.toDouble();
            _currentUserLon = _userProfile?['longitude']?.toDouble();
            if (_currentUserLat != null && _currentUserLon != null) {
              _lastLocationRefresh = now;
            }
            debugPrint(
              'LiveConnect: Using profile location (real-time unavailable)',
            );
          }
          if (mounted) {
            setState(() {
              _isRefreshingLocation = false;
            });
          }
        }
      } else {
        debugPrint(
          'LiveConnect: Using cached location (${_lastLocationRefresh != null ? now.difference(_lastLocationRefresh!).inSeconds : 0}s old)',
        );
      }

      final userLat = _currentUserLat;
      final userLon = _currentUserLon;

      // Build query based on filters - USE INDEXES FOR BETTER PERFORMANCE
      Query<Map<String, dynamic>> usersQuery = _firestore.collection('users');

      // ALWAYS filter by discoveryModeEnabled to respect user privacy
      usersQuery = usersQuery.where('discoveryModeEnabled', isEqualTo: true);

      // Apply city filter if 'City' location filter is selected
      // This uses the composite index: discoveryModeEnabled + city
      if (_locationFilter == 'City' &&
          userCity != null &&
          userCity.isNotEmpty) {
        usersQuery = usersQuery.where('city', isEqualTo: userCity);
      }

      // Apply gender filter at database level when enabled
      // This uses the composite index: discoveryModeEnabled + city + gender OR discoveryModeEnabled + gender
      if (_filterByGender && _selectedGenders.length == 1) {
        // Only apply single-gender filter at DB level (arrayContainsAny doesn't work for equality)
        usersQuery = usersQuery.where(
          'gender',
          isEqualTo: _selectedGenders.first,
        );
      }

      // Apply pagination
      if (loadMore && _lastDocument != null) {
        usersQuery = usersQuery.startAfterDocument(_lastDocument!);
      }

      // Calculate fetch size - need to over-fetch when in-memory filters are active
      // to account for documents that will be filtered out
      int fetchSize = _pageSize;
      bool hasInMemoryFilters = false;

      // Check if we have in-memory filters that might reduce results
      if (_locationFilter == 'Near me') {
        hasInMemoryFilters = true; // Distance filtering
      }
      if (_filterByInterests && _selectedInterests.isNotEmpty) {
        hasInMemoryFilters = true;
      }
      if (_filterByGender && _selectedGenders.length > 1) {
        hasInMemoryFilters = true; // Multi-gender
      }
      if (_filterByConnectionTypes && _selectedConnectionTypes.isNotEmpty) {
        hasInMemoryFilters = true;
      }
      if (_filterByActivities && _selectedActivities.isNotEmpty) {
        hasInMemoryFilters = true;
      }
      if (_selectedNetworkingCategory != 'All') {
        hasInMemoryFilters = true;
      }
      if (_ageRange.start > 18 || _ageRange.end < 60) {
        hasInMemoryFilters = true;
      }
      if (_showOnlineOnly) {
        hasInMemoryFilters = true;
      }

      // Over-fetch by 3x when in-memory filters are active to ensure we get enough results
      if (hasInMemoryFilters) {
        fetchSize = _pageSize * 3; // Fetch 60 instead of 20
      }

      usersQuery = usersQuery.limit(fetchSize);
      final usersSnapshot = await usersQuery.get();

      List<Map<String, dynamic>> people = [];
      for (var doc in usersSnapshot.docs) {
        try {
          if (doc.id == userId) continue; // Skip current user

          final userData = doc.data();

          // Note: discoveryModeEnabled is now filtered at database level for better performance

          final userInterests = List<String>.from(userData['interests'] ?? []);
          final otherUserCity = userData['city'];
          final otherUserLat = userData['latitude']?.toDouble();
          final otherUserLon = userData['longitude']?.toDouble();

          // Calculate distance when both users have location data
          // (for filtering with "Near me" and for displaying on cards)
          double? distance;
          if (userLat != null &&
              userLon != null &&
              otherUserLat != null &&
              otherUserLon != null) {
            distance = _calculateDistance(
              userLat,
              userLon,
              otherUserLat,
              otherUserLon,
            );
          }
          // Optimization: If location data is missing, distance stays null and won't be displayed

          // Apply location filtering based on _locationFilter
          if (_locationFilter == 'Near me') {
            // Skip if no distance data
            if (distance == null) continue;

            // Skip if user is outside the distance range
            if (distance < _distanceRange.start ||
                distance > _distanceRange.end)
              continue;
          } else if (_locationFilter == 'City') {
            // Additional city check for cases where query didn't filter
            if (userCity != null && userCity.isNotEmpty) {
              if (otherUserCity == null || otherUserCity != userCity) {
                continue; // Skip if not in same city
              }
            }
          }
          // 'Worldwide' has no location filtering

          // Calculate common interests
          List<String> commonInterests = [];
          double matchScore =
              1.0; // Default match score when interest filter is off

          if (_filterByInterests && _selectedInterests.isNotEmpty) {
            commonInterests = _selectedInterests
                .where((interest) => userInterests.contains(interest))
                .toList();

            // Skip if no common interests when filter is on
            if (commonInterests.isEmpty) continue;

            matchScore = commonInterests.length / _selectedInterests.length;
          } else {
            // When interest filter is off, show all their interests as "common"
            commonInterests = userInterests;
          }

          // Gender filtering (only needed for multiple genders - single gender filtered at DB level)
          if (_filterByGender && _selectedGenders.length > 1) {
            final userGender = userData['gender'] as String?;

            // Skip if user has no gender or gender is not in selected genders
            if (userGender == null || !_selectedGenders.contains(userGender)) {
              continue;
            }
          }
          // Note: Single gender filter is applied at database level for better performance

          // Connection Types filtering
          if (_filterByConnectionTypes && _selectedConnectionTypes.isNotEmpty) {
            final userConnectionTypes = List<String>.from(
              userData['connectionTypes'] ?? [],
            );

            // Check if user has any of the selected connection types
            final hasMatchingType = _selectedConnectionTypes.any(
              (type) => userConnectionTypes.contains(type),
            );

            if (!hasMatchingType) continue;
          }

          // Activities filtering
          if (_filterByActivities && _selectedActivities.isNotEmpty) {
            final userActivities = List<String>.from(
              userData['activities'] ?? [],
            );

            // Check if user has any of the selected activities
            final hasMatchingActivity = _selectedActivities.any(
              (activity) => userActivities.contains(activity),
            );

            if (!hasMatchingActivity) continue;
          }

          // Networking category filtering
          if (_selectedNetworkingCategory != 'All') {
            final userNetworkingCategory =
                userData['networkingCategory'] as String?;
            final userSubcategory =
                userData['networkingSubcategory'] as String?;
            if (userNetworkingCategory == null ||
                userNetworkingCategory != _selectedNetworkingCategory) {
              continue;
            }
            // Also filter by subcategory if selected
            if (_selectedSubcategory != null) {
              if (userSubcategory == null ||
                  userSubcategory != _selectedSubcategory) {
                continue;
              }
            }
          }

          // Age range filtering
          if (_ageRange.start > 18 || _ageRange.end < 60) {
            final userAge = userData['age'] as int?;
            if (userAge != null) {
              if (userAge < _ageRange.start.round() ||
                  userAge > _ageRange.end.round()) {
                continue;
              }
            }
          }

          // Online only filtering
          if (_showOnlineOnly) {
            final isOnline = userData['isOnline'] as bool? ?? false;
            if (!isOnline) continue;
          }

          // Add user with match data
          people.add({
            'userId': doc.id,
            'userData': userData,
            'commonInterests': commonInterests,
            'matchScore': matchScore,
            'distance': distance, // Add distance for display
          });
        } catch (e) {
          // Skip user if there's an error processing their data
          debugPrint('Error processing user ${doc.id}: $e');
          continue;
        }
      }

      // Always sort by distance (closest first), users without distance go to end
      people.sort((a, b) {
        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;

        // Both have distance - sort by closest first
        if (distA != null && distB != null) {
          return distA.compareTo(distB);
        }

        // Only A has distance - A comes first
        if (distA != null && distB == null) return -1;

        // Only B has distance - B comes first
        if (distA == null && distB != null) return 1;

        // Neither has distance - sort by match score
        return (b['matchScore'] as double).compareTo(a['matchScore'] as double);
      });

      if (mounted) {
        setState(() {
          // Update pagination state
          if (usersSnapshot.docs.isNotEmpty) {
            _lastDocument = usersSnapshot.docs.last;
          }
          // Has more if we fetched the full fetch size
          // (not _pageSize, but the actual size we requested)
          _hasMoreUsers = usersSnapshot.docs.length >= fetchSize;

          // Limit final results to _pageSize even if we fetched more
          if (people.length > _pageSize) {
            people = people.sublist(0, _pageSize);
          }

          // Update people list
          if (loadMore) {
            _nearbyPeople.addAll(people);
            _isLoadingMore = false;
          } else {
            _nearbyPeople = people;
            _isLoadingPeople = false;
          }

          // Apply search filter if search query exists
          _applySearchFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby people: $e');
      if (mounted) {
        setState(() {
          _isLoadingPeople = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to load nearby users. Please check your connection.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadNearbyPeople();
              },
            ),
          ),
        );
      }
    }
  }

  // Filter people based on search query
  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredPeople = _nearbyPeople;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredPeople = _nearbyPeople.where((person) {
        final userData = person['userData'] as Map<String, dynamic>;
        final name = (userData['name'] ?? '').toString().toLowerCase();
        final interests = List<String>.from(userData['interests'] ?? []);

        // Search in name
        if (name.contains(query)) return true;

        // Search in interests
        for (final interest in interests) {
          if (interest.toLowerCase().contains(query)) return true;
        }

        // Search in city
        final city = (userData['city'] ?? '').toString().toLowerCase();
        if (city.contains(query)) return true;

        return false;
      }).toList();
    }
  }

  // Helper method to calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c;

    return distance;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _updateInterests() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'interests': _selectedInterests,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interests updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload nearby people
      _loadNearbyPeople();
    } catch (e) {
      debugPrint('Error updating interests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to save interests. Please try again.'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showInterestsDialog() {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedInterests);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Your Interests'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableInterests.length,
                  itemBuilder: (context, index) {
                    final interest = _availableInterests[index];
                    final isSelected = tempSelected.contains(interest);

                    return CheckboxListTile(
                      title: Text(interest),
                      value: isSelected,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(interest);
                          } else {
                            tempSelected.remove(interest);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests = tempSelected;
                    });
                    Navigator.pop(context);
                    _updateInterests();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showFilterDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;

              return Scaffold(
                backgroundColor: Colors.transparent,
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  centerTitle: true,
                  toolbarHeight: 56,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Filter Options',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                        bottom: BorderSide(color: Colors.white, width: 0.5),
                      ),
                    ),
                  ),
                ),
                body: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(64, 64, 64, 1),
                        Color.fromRGBO(0, 0, 0, 1),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Networking Categories Section
                                Row(
                                  children: [
                                    Text(
                                      'Categories',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedNetworkingCategory != 'All')
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedNetworkingCategory = 'All';
                                            _selectedSubcategory = null;
                                            _categoryDropdownSelections.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Category Dropdown
                                LayoutBuilder(
                                  builder: (_, boxConstraints) => PopupMenuButton<String>(
                                    constraints: BoxConstraints(
                                      minWidth: boxConstraints.maxWidth,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    color: const Color(0xFF2A2A2A),
                                    position: PopupMenuPosition.under,
                                    borderRadius: BorderRadius.circular(14),
                                    initialValue:
                                        _selectedNetworkingCategory == 'All'
                                        ? null
                                        : _selectedNetworkingCategory,
                                    itemBuilder: (context) =>
                                        _networkingCategoryData.entries.map((
                                          entry,
                                        ) {
                                          final catName = entry.key;
                                          final catData = entry.value;
                                          final icon =
                                              catData['icon'] as IconData;
                                          final color =
                                              catData['color'] as Color;
                                          return PopupMenuItem<String>(
                                            value: catName,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  icon,
                                                  color: color,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  catName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                    onSelected: (value) {
                                      setDialogState(() {
                                        _selectedNetworkingCategory = value;
                                        _selectedSubcategory = null;
                                        _selectedConnectionTypes.clear();
                                        _filterByConnectionTypes = false;
                                        _selectedActivities.clear();
                                        _filterByActivities = false;
                                        _categoryDropdownSelections.clear();
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (_selectedNetworkingCategory !=
                                              'All') ...[
                                            Icon(
                                              _networkingCategoryData[_selectedNetworkingCategory]!['icon']
                                                  as IconData,
                                              color:
                                                  _networkingCategoryData[_selectedNetworkingCategory]!['color']
                                                      as Color,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          Expanded(
                                            child: Text(
                                              _selectedNetworkingCategory ==
                                                      'All'
                                                  ? 'Select Category'
                                                  : _selectedNetworkingCategory,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Subcategory Dropdown — shown when a category is selected
                                if (_selectedNetworkingCategory != 'All') ...[
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final catData =
                                          _networkingCategoryData[_selectedNetworkingCategory]!;
                                      final color = catData['color'] as Color;
                                      final subs =
                                          catData['subs'] as List<String>;

                                      return LayoutBuilder(
                                        builder: (_, boxConstraints) =>
                                            PopupMenuButton<String>(
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    boxConstraints.maxWidth,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              color: const Color(0xFF2A2A2A),
                                              position: PopupMenuPosition.under,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              initialValue:
                                                  _selectedSubcategory,
                                              itemBuilder: (context) => subs
                                                  .map(
                                                    (
                                                      sub,
                                                    ) => PopupMenuItem<String>(
                                                      value: sub,
                                                      child: Text(
                                                        sub,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onSelected: (value) {
                                                setDialogState(() {
                                                  _selectedSubcategory = value;
                                                  _categoryDropdownSelections
                                                      .clear();
                                                });
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 11,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _selectedSubcategory ??
                                                            'Select Subcategory',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color: Colors.white,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                  ),
                                ],

                                // ── Category-Specific Filters (dynamic) ──
                                if (_selectedNetworkingCategory != 'All')
                                  Builder(
                                    builder: (context) {
                                      final catColor =
                                          _networkingCategoryData[_selectedNetworkingCategory]!['color']
                                              as Color;
                                      // Collect filters: category-level + subcategory-level
                                      final filters = <Map<String, dynamic>>[
                                        ...(_categoryFilters[_selectedNetworkingCategory] ??
                                            []),
                                        if (_selectedSubcategory != null)
                                          ...(_subcategoryFilters[_selectedSubcategory] ??
                                              []),
                                      ];
                                      if (filters.isEmpty)
                                        return const SizedBox.shrink();

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: filters.expand<Widget>((
                                          filter,
                                        ) {
                                          final label =
                                              filter['label'] as String;
                                          final options = List<String>.from(
                                            filter['options'] as List,
                                          );

                                          return [
                                            const SizedBox(height: 16),
                                            // Filter label
                                            Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            LayoutBuilder(
                                              builder: (_, boxConstraints) => PopupMenuButton<String>(
                                                constraints: BoxConstraints(
                                                  minWidth:
                                                      boxConstraints.maxWidth,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  side: BorderSide(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                                color: const Color(0xFF2A2A2A),
                                                position:
                                                    PopupMenuPosition.under,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                initialValue:
                                                    _categoryDropdownSelections[label],
                                                itemBuilder: (context) => options
                                                    .map(
                                                      (
                                                        opt,
                                                      ) => PopupMenuItem<String>(
                                                        value: opt,
                                                        child: Text(
                                                          opt,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                                onSelected: (value) {
                                                  setDialogState(() {
                                                    _categoryDropdownSelections[label] =
                                                        value;
                                                  });
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 11,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: catColor.withValues(
                                                      alpha: 0.06,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          _categoryDropdownSelections[label] ??
                                                              'Select $label',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons
                                                            .keyboard_arrow_down_rounded,
                                                        color: Colors.white,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ];
                                        }).toList(),
                                      );
                                    },
                                  ),

                                const SizedBox(height: 12),

                                // ── Gender Filter (Dropdown) ──
                                Row(
                                  children: [
                                    Text(
                                      'Gender',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedGenders.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            _selectedGenders.clear();
                                            _filterByGender = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LayoutBuilder(
                                  builder: (_, boxConstraints) =>
                                      PopupMenuButton<String>(
                                        constraints: BoxConstraints(
                                          minWidth: boxConstraints.maxWidth,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        color: const Color(0xFF2A2A2A),
                                        position: PopupMenuPosition.under,
                                        borderRadius: BorderRadius.circular(14),
                                        initialValue:
                                            _selectedGenders.isNotEmpty
                                            ? _selectedGenders.first
                                            : null,
                                        itemBuilder: (context) =>
                                            [
                                                  'Male',
                                                  'Female',
                                                  'Non-binary',
                                                  'Other',
                                                ]
                                                .map(
                                                  (
                                                    gender,
                                                  ) => PopupMenuItem<String>(
                                                    value: gender,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          gender == 'Male'
                                                              ? Icons.male
                                                              : gender ==
                                                                    'Female'
                                                              ? Icons.female
                                                              : Icons
                                                                    .transgender,
                                                          color: const Color(
                                                            0xFFFF6B9D,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Text(
                                                          gender,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onSelected: (value) {
                                          setDialogState(() {
                                            _selectedGenders.clear();
                                            _selectedGenders.add(value);
                                            _filterByGender = true;
                                          });
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 11,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              if (_selectedGenders
                                                  .isNotEmpty) ...[
                                                Icon(
                                                  _selectedGenders.first ==
                                                          'Male'
                                                      ? Icons.male
                                                      : _selectedGenders
                                                                .first ==
                                                            'Female'
                                                      ? Icons.female
                                                      : Icons.transgender,
                                                  color: const Color(
                                                    0xFFFF6B9D,
                                                  ),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  _selectedGenders.isNotEmpty
                                                      ? _selectedGenders.first
                                                      : 'Select Gender',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ),

                                const SizedBox(height: 12),

                                // ── Age Range (Dropdowns) ──
                                Row(
                                  children: [
                                    Text(
                                      'Age Range',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    RangeValues tempAge = _ageRange;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => StatefulBuilder(
                                        builder: (ctx, setSliderState) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF2A2A2A,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          title: const Text(
                                            'Age Range',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${tempAge.start.round()} - ${tempAge.end.round() == 60 ? "60+" : tempAge.end.round()}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  activeTrackColor:
                                                      Colors.white,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.2),
                                                  thumbColor: Colors.white,
                                                  overlayColor: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  rangeThumbShape:
                                                      const RoundRangeSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                ),
                                                child: RangeSlider(
                                                  values: tempAge,
                                                  min: 18,
                                                  max: 60,
                                                  divisions: 42,
                                                  onChanged: (values) {
                                                    setSliderState(() {
                                                      tempAge = values;
                                                    });
                                                  },
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    '18',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Text(
                                                    '60+',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setDialogState(() {
                                                  _ageRange = tempAge;
                                                });
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_ageRange.start.round()} - ${_ageRange.end.round() == 60 ? "60+" : _ageRange.end.round()}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ── Location (Distance Dropdowns) ──
                                Row(
                                  children: [
                                    Text(
                                      'Location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    RangeValues tempDist = _distanceRange;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => StatefulBuilder(
                                        builder: (ctx, setSliderState) => AlertDialog(
                                          backgroundColor: const Color(
                                            0xFF2A2A2A,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          title: const Text(
                                            'Location Range',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${tempDist.start.round()} km - ${tempDist.end.round() == 500 ? "500+" : "${tempDist.end.round()}"} km',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SliderTheme(
                                                data: SliderThemeData(
                                                  activeTrackColor:
                                                      Colors.white,
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withValues(alpha: 0.2),
                                                  thumbColor: Colors.white,
                                                  overlayColor: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  rangeThumbShape:
                                                      const RoundRangeSliderThumbShape(
                                                        enabledThumbRadius: 8,
                                                      ),
                                                ),
                                                child: RangeSlider(
                                                  values: tempDist,
                                                  min: 1,
                                                  max: 500,
                                                  divisions: 499,
                                                  onChanged: (values) {
                                                    setSliderState(() {
                                                      tempDist = values;
                                                    });
                                                  },
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    '1 km',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const Text(
                                                    '500+ km',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setDialogState(() {
                                                  _distanceRange = tempDist;
                                                  _locationFilter = 'Near me';
                                                });
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_distanceRange.start.round()} km - ${_distanceRange.end.round() == 500 ? "500+" : "${_distanceRange.end.round()}"} km',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ── Connection Types (Dropdown, only if relevant) ──
                                if (_selectedNetworkingCategory == 'All' ||
                                    (_categoryConnectionGroups[_selectedNetworkingCategory] ??
                                            [])
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Connection Types',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_selectedConnectionTypes.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              _selectedConnectionTypes.clear();
                                              _filterByConnectionTypes = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      // Build flat list of connection types from relevant groups
                                      final relevantGroups =
                                          _selectedNetworkingCategory == 'All'
                                          ? _connectionTypeGroups
                                          : Map.fromEntries(
                                              (_categoryConnectionGroups[_selectedNetworkingCategory] ??
                                                      _connectionTypeGroups.keys
                                                          .toList())
                                                  .where(
                                                    (key) =>
                                                        _connectionTypeGroups
                                                            .containsKey(key),
                                                  )
                                                  .map(
                                                    (key) => MapEntry(
                                                      key,
                                                      _connectionTypeGroups[key]!,
                                                    ),
                                                  ),
                                            );
                                      final allTypes = <String>[];
                                      for (final group
                                          in relevantGroups.entries) {
                                        for (final type in group.value) {
                                          allTypes.add(type);
                                        }
                                      }
                                      return LayoutBuilder(
                                        builder: (_, boxConstraints) =>
                                            PopupMenuButton<String>(
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    boxConstraints.maxWidth,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              color: const Color(0xFF2A2A2A),
                                              position: PopupMenuPosition.under,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              initialValue:
                                                  _selectedConnectionTypes
                                                      .isNotEmpty
                                                  ? _selectedConnectionTypes
                                                        .first
                                                  : null,
                                              itemBuilder: (context) => allTypes
                                                  .map(
                                                    (
                                                      type,
                                                    ) => PopupMenuItem<String>(
                                                      value: type,
                                                      child: Text(
                                                        type,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onSelected: (value) {
                                                setDialogState(() {
                                                  _selectedConnectionTypes
                                                      .clear();
                                                  _selectedConnectionTypes.add(
                                                    value,
                                                  );
                                                  _filterByConnectionTypes =
                                                      true;
                                                });
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 11,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _selectedConnectionTypes
                                                                .isNotEmpty
                                                            ? _selectedConnectionTypes
                                                                  .first
                                                            : 'Select Connection Type',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color: Colors.white,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                  ),
                                ],

                                // ── Activities (Dropdown, only if relevant for selected category) ──
                                if (_selectedNetworkingCategory == 'All' ||
                                    (_categoryActivityGroups[_selectedNetworkingCategory] ??
                                            [])
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Activities',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_selectedActivities.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              _selectedActivities.clear();
                                              _filterByActivities = false;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final relevantGroups =
                                          _selectedNetworkingCategory == 'All'
                                          ? _activityGroups
                                          : Map.fromEntries(
                                              (_categoryActivityGroups[_selectedNetworkingCategory] ??
                                                      _activityGroups.keys
                                                          .toList())
                                                  .where(
                                                    (key) => _activityGroups
                                                        .containsKey(key),
                                                  )
                                                  .map(
                                                    (key) => MapEntry(
                                                      key,
                                                      _activityGroups[key]!,
                                                    ),
                                                  ),
                                            );
                                      final allActivities = <String>[];
                                      for (final group
                                          in relevantGroups.entries) {
                                        for (final activity in group.value) {
                                          allActivities.add(activity);
                                        }
                                      }
                                      return LayoutBuilder(
                                        builder: (_, boxConstraints) =>
                                            PopupMenuButton<String>(
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    boxConstraints.maxWidth,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              color: const Color(0xFF2A2A2A),
                                              position: PopupMenuPosition.under,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              initialValue:
                                                  _selectedActivities.isNotEmpty
                                                  ? _selectedActivities.first
                                                  : null,
                                              itemBuilder: (context) =>
                                                  allActivities
                                                      .map(
                                                        (
                                                          activity,
                                                        ) => PopupMenuItem<String>(
                                                          value: activity,
                                                          child: Text(
                                                            activity,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                              onSelected: (value) {
                                                setDialogState(() {
                                                  _selectedActivities.clear();
                                                  _selectedActivities.add(
                                                    value,
                                                  );
                                                  _filterByActivities = true;
                                                });
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 11,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _selectedActivities
                                                                .isNotEmpty
                                                            ? _selectedActivities
                                                                  .first
                                                            : 'Select Activity',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      color: Colors.white,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // ── Show Online Only ──
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _showOnlineOnly
                                              ? const Color(0xFF00E676)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                          boxShadow: _showOnlineOnly
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF00E676,
                                                    ).withValues(alpha: 0.6),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Show Online Only',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 24,
                                        width: 40,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: Switch(
                                            value: _showOnlineOnly,
                                            onChanged: (value) {
                                              setDialogState(() {
                                                _showOnlineOnly = value;
                                              });
                                            },
                                            activeTrackColor: const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.5),
                                            activeThumbColor: const Color(
                                              0xFF00E676,
                                            ),
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

                        // Action Buttons
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF016CFF),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF016CFF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    // Reload after filter dialog is fully closed
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {});
                                          _loadNearbyPeople();
                                        });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF016CFF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
            },
          );
        },
      ),
    );
  }

  // Helper method to get gradient colors based on user name
  List<Color> _getAvatarGradient(String name) {
    final hash = name.hashCode % 5;
    switch (hash) {
      case 0:
        return [const Color(0xFFFF6B9D), const Color(0xFFC7365F)]; // Pink
      case 1:
        return [const Color(0xFF4A90E2), const Color(0xFF2E5BFF)]; // Blue
      case 2:
        return [const Color(0xFFFF6B35), const Color(0xFFFF4E00)]; // Orange
      case 3:
        return [const Color(0xFF9B59B6), const Color(0xFF6C3483)]; // Purple
      default:
        return [const Color(0xFF00D67D), const Color(0xFF00A85E)]; // Green
    }
  }

  /// Check if user is truly online based on lastSeen timestamp
  /// User is considered online only if lastSeen is within last 5 minutes
  void _showProfileDetail(ExtendedUserProfile user) async {
    debugPrint('_showProfileDetail called for user: ${user.name}');
    final bool isDummyUser = user.uid.startsWith('dummy_');
    // Check connection status before navigating (with error handling)
    String? connectionStatus;
    bool isConnected = false;

    if (!isDummyUser) {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null) {
          connectionStatus = await _connectionService
              .getConnectionRequestStatus(user.uid);
          isConnected = await _connectionService.areUsersConnected(
            currentUserId,
            user.uid,
          );
        }
      } catch (e) {
        debugPrint('Error checking connection status: $e');
      }
    }

    if (!mounted) return;

    // Determine the status to display
    final displayStatus = isConnected
        ? 'connected'
        : connectionStatus; // 'sent', 'received', or null

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileDetailScreen(
            user: user,
            connectionStatus: displayStatus,
            selectedCategory: _selectedNetworkingCategory != 'All'
                ? _selectedNetworkingCategory
                : null,
            selectedSubcategory: _selectedSubcategory,
            onConnect: isDummyUser || isConnected || connectionStatus == 'sent'
                ? null
                : () async {
                    // OPTIMISTIC UPDATE: Immediately show "Request Sent" in UI
                    updateConnectionCache(
                      user.uid,
                      false,
                      requestStatus: 'sent',
                    );

                    // Send real connection request in background
                    final result = await _connectionService
                        .sendConnectionRequest(receiverId: user.uid);

                    if (!mounted) return;

                    if (result['success']) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(child: Text('Connection request sent!')),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      // Request failed - revert optimistic update
                      updateConnectionCache(
                        user.uid,
                        false,
                        requestStatus: null,
                      );

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  result['message'] ?? 'Failed to send request',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red.shade600,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening profile detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final isGlass = themeState.isGlassmorphism;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildContent(isDarkMode, isGlass),
    );
  }

  Widget _buildContent(bool isDarkMode, bool isGlass) {
    // Show empty state only if interest filter is on AND no interests selected
    if (_filterByInterests && _selectedInterests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Connect with People',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Select your interests to find people with similar interests, or disable the interest filter to see everyone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showInterestsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Select Interests'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_isLoadingPeople) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredPeople.isEmpty &&
        _nearbyPeople.isNotEmpty &&
        _searchQuery.isNotEmpty) {
      // Show search-specific empty state
      return RefreshIndicator(
        onRefresh: () async {
          await _loadNearbyPeople();
        },
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try adjusting your search term',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _applySearchFilter();
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isRefreshingLocation
                              ? null
                              : () async {
                                  await _loadNearbyPeople(
                                    forceRefreshLocation: true,
                                  );
                                },
                          icon: _isRefreshingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _isRefreshingLocation ? 'Refreshing...' : 'Refresh',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Merge real users + dummy cards to always show cards
    final List<_MosaicCardData> allCards = [];

    // Add real users first
    for (int i = 0; i < _filteredPeople.length; i++) {
      final person = _filteredPeople[i];
      final userData = person['userData'] as Map<String, dynamic>;
      final userId = person['userId'] as String;
      final distance = person['distance'] as double?;

      final extendedProfile = ExtendedUserProfile.fromMap(userData, userId);
      final profileWithDistance = extendedProfile.copyWith(distance: distance);

      allCards.add(
        _MosaicCardData(
          profile: profileWithDistance,
          userName: userData['name'] ?? 'Unknown',
          userId: userId,
          isDummy: false,
        ),
      );
    }

    // Test cards for all 12 networking categories (2 per category = 24 cards)
    const List<Map<String, dynamic>> dummyCardData = [
      // Custom card - Abdulla
      {
        'name': 'Abdulla',
        'age': 35,
        'occupation': 'Founder',
        'category': 'Business',
        'subcategory': 'Startup Founders',
        'photo': 'assets/images/abdulla.jpeg',
        'distance': 40.0,
      },
      // 1. Professional
      {
        'name': 'Sophia',
        'age': 28,
        'occupation': 'Recruiter',
        'category': 'Professional',
        'subcategory': 'Recruiters',
      },
      {
        'name': 'Arjun',
        'age': 32,
        'occupation': 'Freelancer',
        'category': 'Professional',
        'subcategory': 'Freelancers',
      },
      // 2. Business
      {
        'name': 'Elena',
        'age': 35,
        'occupation': 'Startup Founder',
        'category': 'Business',
        'subcategory': 'Startup Founders',
      },
      {
        'name': 'Marcus',
        'age': 40,
        'occupation': 'Retailer',
        'category': 'Business',
        'subcategory': 'Retailers',
      },
      // 3. Social
      {
        'name': 'Priya',
        'age': 24,
        'occupation': 'Travel Blogger',
        'category': 'Social',
        'subcategory': 'Travel Companions',
      },
      {
        'name': 'James',
        'age': 26,
        'occupation': 'Event Host',
        'category': 'Social',
        'subcategory': 'Party Buddies',
      },
      // 4. Educational
      {
        'name': 'Aisha',
        'age': 22,
        'occupation': 'Student',
        'category': 'Educational',
        'subcategory': 'Study Groups',
      },
      {
        'name': 'Daniel',
        'age': 30,
        'occupation': 'Tutor',
        'category': 'Educational',
        'subcategory': 'Tutoring',
      },
      // 5. Creative
      {
        'name': 'Mia',
        'age': 25,
        'occupation': 'Photographer',
        'category': 'Creative',
        'subcategory': 'Photography',
      },
      {
        'name': 'Ravi',
        'age': 27,
        'occupation': 'Musician',
        'category': 'Creative',
        'subcategory': 'Music Production',
      },
      // 6. Tech
      {
        'name': 'Emma',
        'age': 29,
        'occupation': 'Software Developer',
        'category': 'Tech',
        'subcategory': 'Software Development',
      },
      {
        'name': 'Carlos',
        'age': 31,
        'occupation': 'Data Scientist',
        'category': 'Tech',
        'subcategory': 'Data Science',
      },
      // 7. Industry
      {
        'name': 'Zara',
        'age': 33,
        'occupation': 'Logistics Manager',
        'category': 'Industry',
        'subcategory': 'Logistics & Supply Chain',
      },
      {
        'name': 'Noah',
        'age': 38,
        'occupation': 'Construction Engineer',
        'category': 'Industry',
        'subcategory': 'Construction',
      },
      // 8. Investment & Finance
      {
        'name': 'Lily',
        'age': 34,
        'occupation': 'Stock Trader',
        'category': 'Investment & Finance',
        'subcategory': 'Stock Market',
      },
      {
        'name': 'Vikram',
        'age': 36,
        'occupation': 'Financial Planner',
        'category': 'Investment & Finance',
        'subcategory': 'Financial Planning',
      },
      // 9. Event & Meetup
      {
        'name': 'Anaya',
        'age': 23,
        'occupation': 'Conference Organizer',
        'category': 'Event & Meetup',
        'subcategory': 'Conferences',
      },
      {
        'name': 'Liam',
        'age': 27,
        'occupation': 'Hackathon Host',
        'category': 'Event & Meetup',
        'subcategory': 'Hackathons',
      },
      // 10. Community
      {
        'name': 'Meera',
        'age': 29,
        'occupation': 'NGO Worker',
        'category': 'Community',
        'subcategory': 'NGO & Nonprofits',
      },
      {
        'name': 'Omar',
        'age': 31,
        'occupation': 'Volunteer Coordinator',
        'category': 'Community',
        'subcategory': 'Volunteering',
      },
      // 11. Personal Development
      {
        'name': 'Ishita',
        'age': 26,
        'occupation': 'Yoga Instructor',
        'category': 'Personal Development',
        'subcategory': 'Meditation & Yoga',
      },
      {
        'name': 'Alex',
        'age': 30,
        'occupation': 'Life Coach',
        'category': 'Personal Development',
        'subcategory': 'Life Coaching',
      },
      // 12. Global / NRI
      {
        'name': 'Sara',
        'age': 28,
        'occupation': 'Immigration Consultant',
        'category': 'Global / NRI',
        'subcategory': 'Immigration',
      },
      {
        'name': 'Rohan',
        'age': 33,
        'occupation': 'International Trader',
        'category': 'Global / NRI',
        'subcategory': 'International Trade',
      },
    ];

    // Always add all dummy cards (including Abdulla as first)
    for (int i = 0; i < dummyCardData.length; i++) {
      final dummyData = dummyCardData[i];
      allCards.add(
        _MosaicCardData(
          profile: null,
          userName: dummyData['name'] as String,
          userId: 'dummy_$i',
          isDummy: true,
          dummyDataIndex: i,
        ),
      );
    }

    // Stylish masonry grid — 5 columns, varied heights, 2D scroll
    const int columnCount = 5;
    const double cardWidth = 145.0;
    const double spacing = 8.0;

    // Scroll to center after first build so user can scroll both left & right
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalScrollController.hasClients &&
          _horizontalScrollController.position.pixels == 0) {
        const totalWidth = (cardWidth + spacing) * columnCount - spacing + 16;
        final screenWidth = MediaQuery.of(context).size.width;
        final centerOffset = (totalWidth - screenWidth) / 2;
        if (centerOffset > 0) {
          _horizontalScrollController.jumpTo(centerOffset);
        }
      }
    });

    // Height patterns per column for Pinterest-style masonry
    const List<double> heightPattern = [180, 240, 200, 260, 210];

    // Distribute cards into columns
    final List<List<int>> columns = List.generate(columnCount, (_) => []);
    for (int i = 0; i < allCards.length; i++) {
      columns[i % columnCount].add(i);
    }

    // Colorful cards — every 3rd card shows in full color
    bool isColorCard(int index) => index % 3 == 0;

    Widget buildCardAt(int index) {
      final card = allCards[index];
      final int col = index % columnCount;
      final int row = index ~/ columnCount;
      final double cardHeight =
          heightPattern[(col + row) % heightPattern.length];

      if (card.isDummy || card.profile == null) {
        final cardData = dummyCardData[card.dummyDataIndex % dummyCardData.length];
        final dummyAge = cardData['age'] as int;
        final dummyOccupation = cardData['occupation'] as String;
        final dummyCategory = cardData['category'] as String;
        final dummySubcategory = cardData['subcategory'] as String;
        final dummyDistance = cardData['distance'] as double? ?? (index * 0.7) + 0.3;
        final dummyOnline = index % 3 == 0;
        final customPhoto = cardData['photo'] as String?;
        final dummyPhoto = customPhoto ?? _getDummyImageUrl(index);

        return _buildMosaicCard(
          userName: card.userName,
          imageUrl: dummyPhoto,
          isCenter: isColorCard(index),
          height: cardHeight,
          onTap: () {
            HapticFeedback.lightImpact();
            // Create a temporary profile with full networking category data
            final dummyProfile = ExtendedUserProfile(
              uid: 'dummy_$index',
              name: card.userName,
              photoUrl: dummyPhoto,
              age: dummyAge,
              occupation: dummyOccupation,
              isOnline: dummyOnline,
              distance: dummyDistance,
              city: 'Nearby',
              networkingCategory: dummyCategory,
              networkingSubcategory: dummySubcategory,
              interests: [dummyCategory, dummyOccupation],
            );
            _showProfileDetail(dummyProfile);
          },
          age: dummyAge,
          profession: dummyOccupation,
          distance: dummyDistance,
          isOnline: dummyOnline,
          networkingCategory: dummyCategory,
        );
      }

      // Use the profile already stored in the card data
      final profile = card.profile!;
      final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(profile.photoUrl);

      return _buildMosaicCard(
        userName: profile.name.isNotEmpty ? profile.name : 'Unknown',
        imageUrl: fixedPhotoUrl,
        isCenter: isColorCard(index),
        height: cardHeight,
        onTap: () => _showProfileDetail(profile),
        userId: card.userId,
        age: profile.age,
        profession: profile.occupation ?? profile.category,
        distance: profile.distance,
        isOnline: profile.isOnline,
        networkingCategory: profile.networkingCategory,
      );
    }

    // Build active filter chips
    final bool hasActiveFilters =
        _selectedNetworkingCategory != 'All' ||
        _selectedGenders.isNotEmpty ||
        (_ageRange.start > 18 || _ageRange.end < 60) ||
        _selectedConnectionTypes.isNotEmpty ||
        _selectedActivities.isNotEmpty ||
        _showOnlineOnly ||
        _locationFilter != 'Worldwide';

    return Column(
      children: [
        // Active filter chips bar
        if (hasActiveFilters)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (_selectedNetworkingCategory != 'All') ...[
                    _buildFilterChip(
                      label: _selectedSubcategory != null
                          ? '$_selectedNetworkingCategory > $_selectedSubcategory'
                          : _selectedNetworkingCategory,
                      color:
                          _networkingCategoryData[_selectedNetworkingCategory]!['color']
                              as Color,
                      onRemove: () {
                        setState(() {
                          _selectedNetworkingCategory = 'All';
                          _selectedSubcategory = null;
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_locationFilter != 'Worldwide') ...[
                    _buildFilterChip(
                      label: _locationFilter == 'Near me'
                          ? 'Near me (${_distanceRange.start.round()}-${_distanceRange.end.round()} km)'
                          : _locationFilter,
                      color: const Color(0xFF00D67D),
                      onRemove: () {
                        setState(() {
                          _locationFilter = 'Worldwide';
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Each gender as separate chip
                  ..._selectedGenders.toList().map(
                    (gender) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: gender,
                        color: const Color(0xFFFF6B9D),
                        onRemove: () {
                          setState(() {
                            _selectedGenders.remove(gender);
                            if (_selectedGenders.isEmpty) {
                              _filterByGender = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  if (_ageRange.start > 18 || _ageRange.end < 60) ...[
                    _buildFilterChip(
                      label:
                          'Age ${_ageRange.start.round()}-${_ageRange.end.round() == 60 ? "60+" : "${_ageRange.end.round()}"}',
                      color: const Color(0xFFFFB74D),
                      onRemove: () {
                        setState(() {
                          _ageRange = const RangeValues(18, 60);
                        });
                        _loadNearbyPeople();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Each connection type as separate chip
                  ..._selectedConnectionTypes.toList().map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: type,
                        color: const Color(0xFF7C4DFF),
                        onRemove: () {
                          setState(() {
                            _selectedConnectionTypes.remove(type);
                            if (_selectedConnectionTypes.isEmpty) {
                              _filterByConnectionTypes = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  // Each activity as separate chip
                  ..._selectedActivities.toList().map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        label: activity,
                        color: const Color(0xFF26C6DA),
                        onRemove: () {
                          setState(() {
                            _selectedActivities.remove(activity);
                            if (_selectedActivities.isEmpty) {
                              _filterByActivities = false;
                            }
                          });
                          _loadNearbyPeople();
                        },
                      ),
                    ),
                  ),
                  if (_showOnlineOnly) ...[
                    _buildFilterChip(
                      label: 'Online',
                      color: const Color(0xFF00E676),
                      onRemove: () {
                        setState(() {
                          _showOnlineOnly = false;
                        });
                        _loadNearbyPeople();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        // People grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadNearbyPeople(forceRefreshLocation: true);
            },
            color: const Color(0xFF00D67D),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 90),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(columnCount, (colIndex) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: colIndex < columnCount - 1 ? spacing : 0,
                        ),
                        child: SizedBox(
                          width: cardWidth,
                          child: Column(
                            children: columns[colIndex].map((cardIndex) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: spacing),
                                child: buildCardAt(cardIndex),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // Dummy image URLs for placeholder cards
  static const _dummyImageUrls = [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1502823403499-6ccfcf4fb453?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&h=600&fit=crop',
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=600&fit=crop',
  ];

  String _getDummyImageUrl(int index) {
    return _dummyImageUrls[index % _dummyImageUrls.length];
  }

  /// Stylish mosaic card with glassmorphism info overlay
  Widget _buildMosaicCard({
    required String userName,
    required String? imageUrl,
    required bool isCenter,
    required VoidCallback onTap,
    required double height,
    String? userId,
    int? age,
    String? profession,
    double? distance,
    bool isOnline = false,
    String? networkingCategory,
  }) {
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final gradientColors = _getAvatarGradient(userName);
    final firstName = userName.split(' ').first;

    // Gradient background for placeholder / behind transparent images
    final bgGradient = BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    final placeholderWidget = Container(
      decoration: bgGradient,
      child: Center(
        child: Text(
          userInitial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    // Build the image widget
    final bool isAssetImage =
        imageUrl != null && imageUrl.startsWith('assets/');
    final bool isGooglePhoto =
        imageUrl != null && imageUrl.contains('googleusercontent.com');
    Widget imageWidget;
    if (isAssetImage) {
      imageWidget = SizedBox.expand(
        child: Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Asset load error: $error');
            return placeholderWidget;
          },
        ),
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder: (context, url) => placeholderWidget,
        errorWidget: (context, url, error) {
          if (error.toString().contains('429')) {
            PhotoUrlHelper.markAsRateLimited(url);
          }
          return placeholderWidget;
        },
        // imageBuilder forces the image to fill the entire card
        imageBuilder: (context, imageProvider) {
          final child = SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            ),
          );
          // Google photos are circular PNGs — scale 1.5x so circle fills rectangle
          if (isGooglePhoto) {
            return ClipRect(child: Transform.scale(scale: 1.5, child: child));
          }
          return child;
        },
      );
    } else {
      imageWidget = placeholderWidget;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            if (isCenter)
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image fills entire card
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: isCenter
                      ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        )
                      : const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.saturation,
                        ),
                  child: imageWidget,
                ),
              ),

              // Networking category badge at top-left
              if (networkingCategory != null && networkingCategory.isNotEmpty)
                Positioned(
                  top: 6,
                  left: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          networkingCategory,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Glassmorphism info card at bottom
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name + age row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  age != null ? '$firstName, $age' : firstName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // Online dot
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF00E676)
                                      : Colors.grey.shade500,
                                  shape: BoxShape.circle,
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00E676,
                                            ).withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          // Profession only
                          if (profession != null && profession.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                profession,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          // Distance
                          if (distance != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 10,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    distance < 1
                                        ? '${(distance * 1000).toInt()} m'
                                        : '${distance.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 10,
                                    ),
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

              // Subtle top-right shine for color cards
              if (isCenter)
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
