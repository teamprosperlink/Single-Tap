import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateNetworkingProfileScreen extends StatefulWidget {
  const CreateNetworkingProfileScreen({super.key});

  @override
  State<CreateNetworkingProfileScreen> createState() =>
      _CreateNetworkingProfileScreenState();
}

class _CreateNetworkingProfileScreenState
    extends State<CreateNetworkingProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late AnimationController _shimmerController;

  // Form controllers
  final _nameController = TextEditingController();
  final _aboutMeController = TextEditingController();
  final _occupationController = TextEditingController();

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _currentPhotoUrl;

  // Active status & location
  bool _discoveryModeEnabled = true;
  RangeValues _ageRange = const RangeValues(18, 60);
  RangeValues _distanceRange = const RangeValues(1, 500);
  String? _locationCity;

  // Selected values
  String? _selectedGender;
  String? _selectedCategory;
  String? _selectedSubcategory;
  final Map<String, String> _categoryFilterValues = {};
  final List<String> _selectedConnectionTypes = [];
  final List<String> _selectedActivities = [];
  final List<String> _selectedInterests = [];

  bool _isSaving = false;

  // ── Categories → Subcategories ──
  static const Map<String, List<String>> _categorySubcategories = {
    'Professional': [
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
    'Business': [
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
    'Social': [
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
    'Educational': [
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
    'Creative': [
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
    'Tech': [
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
    'Industry': [
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
    'Investment & Finance': [
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
    'Event & Meetup': [
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
    'Community': [
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
    'Personal Development': [
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
    'Global / NRI': [
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
  };

  // ── Category icons ──
  static const Map<String, IconData> _categoryIcons = {
    'Professional': Icons.business_center_rounded,
    'Business': Icons.storefront_rounded,
    'Social': Icons.groups_rounded,
    'Educational': Icons.school_rounded,
    'Creative': Icons.palette_rounded,
    'Tech': Icons.computer_rounded,
    'Industry': Icons.factory_rounded,
    'Investment & Finance': Icons.account_balance_rounded,
    'Event & Meetup': Icons.event_rounded,
    'Community': Icons.volunteer_activism_rounded,
    'Personal Development': Icons.self_improvement_rounded,
    'Global / NRI': Icons.public_rounded,
  };

  // ── Category colors ──
  static const Map<String, List<Color>> _categoryColors = {
    'Professional': [Color(0xFF6366F1), Color(0xFF818CF8)],
    'Business': [Color(0xFF10B981), Color(0xFF34D399)],
    'Social': [Color(0xFFEC4899), Color(0xFFF472B6)],
    'Educational': [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    'Creative': [Color(0xFFA855F7), Color(0xFFC084FC)],
    'Tech': [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    'Industry': [Color(0xFFF97316), Color(0xFFFB923C)],
    'Investment & Finance': [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    'Event & Meetup': [Color(0xFFEF4444), Color(0xFFF87171)],
    'Community': [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    'Personal Development': [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    'Global / NRI': [Color(0xFFD946EF), Color(0xFFE879F9)],
  };

  // ── Category-specific filters ──
  static const Map<String, List<Map<String, dynamic>>> _categoryFilters = {
    'Professional': [
      {
        'label': 'Experience Level',
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
        'options': ['On-Site', 'Remote', 'Hybrid'],
      },
      {
        'label': 'Industry',
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
        'options': ['Solo', '2-10', '11-50', '51-200', '201-1000', '1000+'],
      },
      {
        'label': 'Business Model',
        'options': ['B2B', 'B2C', 'D2C', 'Marketplace', 'SaaS', 'Subscription'],
      },
      {
        'label': 'Industry Sector',
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
        'options': ['Now', 'Today', 'This Week', 'This Weekend', 'Flexible'],
      },
      {
        'label': 'Interests',
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
        'options': ['Beginner', 'Intermediate', 'Advanced', 'Expert'],
      },
      {
        'label': 'Format',
        'options': ['In-Person', 'Online Live', 'Self-Paced', 'Hybrid'],
      },
      {
        'label': 'Subject',
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
        'options': ['Has Portfolio', 'No Portfolio'],
      },
    ],
    'Tech': [
      {
        'label': 'Experience Level',
        'options': [
          'Junior (0-2 yr)',
          'Mid (2-5 yr)',
          'Senior (5-10 yr)',
          'Lead/Architect (10+ yr)',
        ],
      },
      {
        'label': 'Tech Stack',
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
        'options': ['Local', 'National', 'International'],
      },
      {
        'label': 'Certifications',
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
        'options': ['Beginner', 'Intermediate', 'Advanced', 'Professional'],
      },
      {
        'label': 'Risk Appetite',
        'options': [
          'Conservative',
          'Moderate',
          'Aggressive',
          'Very Aggressive',
        ],
      },
      {
        'label': 'Investment Horizon',
        'options': [
          'Short-Term (< 1yr)',
          'Medium (1-3yr)',
          'Long-Term (3-10yr)',
          'Very Long (10+yr)',
        ],
      },
      {
        'label': 'Purpose',
        'options': ['Invest', 'Raise Capital', 'Advise', 'Learn', 'Partner'],
      },
    ],
    'Event & Meetup': [
      {
        'label': 'Event Format',
        'options': ['In-Person', 'Online', 'Hybrid'],
      },
      {
        'label': 'When',
        'options': ['Today', 'This Week', 'This Weekend', 'This Month'],
      },
      {
        'label': 'Time of Day',
        'options': ['Morning', 'Afternoon', 'Evening', 'Night'],
      },
      {
        'label': 'Price',
        'options': ['Free', 'Paid'],
      },
    ],
    'Community': [
      {
        'label': 'Involvement',
        'options': ['Volunteer', 'Donate', 'Organize', 'Advocate', 'Mentor'],
      },
      {
        'label': 'Commitment',
        'options': ['One-Time', 'Weekly', 'Monthly', 'Ongoing', 'Seasonal'],
      },
      {
        'label': 'Cause Area',
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
        'options': ['Beginner', 'Intermediate', 'Advanced'],
      },
      {
        'label': 'Format',
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
        'options': ['15 min', '30 min', '45 min', '1 hr', '2 hr'],
      },
      {
        'label': 'Goal',
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

  // ── Subcategory-Specific Filters ──
  static const Map<String, List<Map<String, dynamic>>> _subcategoryFilters = {
    // Professional
    'Job Seekers': [
      {
        'label': 'Education',
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
        'options': ['Hourly', 'Fixed-Price', 'Retainer', 'Equity'],
      },
    ],
    'Consultants': [
      {
        'label': 'Specialty',
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
    // Business
    'Startup Founders': [
      {
        'label': 'Funding Stage',
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
        'options': ['Angel', 'VC', 'PE', 'Debt', 'Crypto'],
      },
      {
        'label': 'Preferred Stage',
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
        'options': ['Food', 'Retail', 'Service', 'Education', 'Fitness'],
      },
    ],
    // Social
    'Dating': [
      {
        'label': 'Relationship Goal',
        'options': ['Serious', 'Casual', 'Open to Anything'],
      },
      {
        'label': 'Lifestyle',
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
        'options': ['Budget', 'Mid-Range', 'Luxury', 'Backpacking'],
      },
      {
        'label': 'Trip Duration',
        'options': ['Weekend', '1 Week', '2+ Weeks', 'Long-Term'],
      },
    ],
    'Roommates': [
      {
        'label': 'Lifestyle',
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
        'options': ['Clubs', 'Bars', 'House Parties', 'Live Music', 'Rooftops'],
      },
      {
        'label': 'Music Taste',
        'options': ['EDM', 'Hip-Hop', 'Bollywood', 'Rock', 'Pop', 'Jazz'],
      },
    ],
    // Educational
    'Exam Prep': [
      {
        'label': 'Exam Type',
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
        'options': ['4 Weeks', '8 Weeks', '12 Weeks', '6 Months'],
      },
    ],
    'Study Groups': [
      {
        'label': 'Group Size',
        'options': ['2-3', '4-6', '7-10', '10+'],
      },
    ],
    // Creative
    'Photography': [
      {
        'label': 'Style',
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
        'options': ['Video', 'Photo', 'Written', 'Audio', 'Mixed Media'],
      },
    ],
    'Writing & Blogging': [
      {
        'label': 'Niche',
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
    // Tech
    'Software Development': [
      {
        'label': 'Domain',
        'options': ['Backend', 'Frontend', 'Full-Stack', 'Embedded', 'Systems'],
      },
    ],
    'Mobile Apps': [
      {
        'label': 'Platform',
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
        'options': ['AWS', 'Azure', 'GCP', 'Multi-Cloud'],
      },
    ],
    'Data Science': [
      {
        'label': 'Tools',
        'options': ['Python', 'R', 'SQL', 'Tableau', 'Power BI', 'Spark'],
      },
    ],
    'Blockchain': [
      {
        'label': 'Chain',
        'options': ['Ethereum', 'Solana', 'Bitcoin', 'Polygon', 'Polkadot'],
      },
      {
        'label': 'Focus',
        'options': ['Smart Contracts', 'DeFi', 'NFT', 'DApp', 'Web3'],
      },
    ],
    'UI/UX Design': [
      {
        'label': 'Tools',
        'options': ['Figma', 'Sketch', 'Adobe XD', 'Framer', 'InVision'],
      },
    ],
    // Industry
    'Manufacturing': [
      {
        'label': 'Capacity',
        'options': ['Small Batch', 'Medium', 'Large Scale', 'Mass Production'],
      },
    ],
    'Construction': [
      {
        'label': 'Project Type',
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
        'options': ['Buy', 'Sell', 'Rent', 'Lease'],
      },
    ],
    'Agriculture': [
      {
        'label': 'Product',
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
        'options': ['Generic', 'Branded', 'API', 'Biotech', 'Medical Devices'],
      },
    ],
    'Food Processing': [
      {
        'label': 'Category',
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
    // Investment & Finance
    'Stock Market': [
      {
        'label': 'Sector',
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
        'options': ['Micro', 'Small', 'Mid', 'Large', 'Mega'],
      },
    ],
    'Cryptocurrency': [
      {
        'label': 'Token Type',
        'options': ['Layer 1', 'Layer 2', 'DeFi', 'NFT', 'Stablecoin', 'Meme'],
      },
    ],
    'Mutual Funds': [
      {
        'label': 'Fund Type',
        'options': ['Equity', 'Debt', 'Hybrid', 'Index', 'ELSS', 'Liquid'],
      },
    ],
    'Angel Investing': [
      {
        'label': 'Preferred Sector',
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
        'options': ['Pre-Seed', 'Seed', 'Series A', 'Series B', 'Series C+'],
      },
    ],
    'Financial Planning': [
      {
        'label': 'Goal',
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
    // Event & Meetup
    'Hackathons': [
      {
        'label': 'Theme',
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
        'options': ['Solo', '2-3', '4-5', 'Open'],
      },
    ],
    'Conferences': [
      {
        'label': 'Audience',
        'options': ['Beginner', 'Professional', 'Executive', 'Academic'],
      },
    ],
    'Sports Events': [
      {
        'label': 'Sport',
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
        'options': ['Participate', 'Spectate', 'Volunteer'],
      },
    ],
    'Concerts & Music': [
      {
        'label': 'Genre',
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
    // Community
    'Volunteering': [
      {
        'label': 'Availability',
        'options': ['Weekdays', 'Weekends', 'Evenings', 'Flexible'],
      },
    ],
    'Environmental': [
      {
        'label': 'Focus',
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
        'options': ['6-10', '11-14', '15-18', '18-25'],
      },
      {
        'label': 'Program Type',
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
    // Personal Development
    'Fitness & Gym': [
      {
        'label': 'Workout Type',
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
        'options': ['1 Chapter/Week', 'Whole Book', 'Audio + Discussion'],
      },
    ],
    // Global / NRI
    'Immigration': [
      {
        'label': 'Visa Category',
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
        'options': ['Fall', 'Spring', 'Summer', 'Rolling'],
      },
    ],
    'Overseas Jobs': [
      {
        'label': 'Contract Type',
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
        'options': ['Import', 'Export', 'Both'],
      },
      {
        'label': 'Volume',
        'options': ['Small', 'Medium', 'Large', 'Bulk'],
      },
    ],
    'Relocation Help': [
      {
        'label': 'Service Needed',
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

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _loadBasicUserInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shimmerController.dispose();
    _nameController.dispose();
    _aboutMeController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _loadBasicUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || doc.data() == null || !mounted) return;

      final data = doc.data()!;
      setState(() {
        // Only load basic user info (name & photo), NOT networking-specific fields
        _nameController.text = data['name'] ?? data['displayName'] ?? '';
        _currentPhotoUrl = data['photoUrl'];
        _locationCity = data['city'] ?? data['location'];
      });
    } catch (e) {
      debugPrint('Error loading basic user info: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('Please login first', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload image if selected
      String? photoUrl = _currentPhotoUrl;
      if (_selectedImage != null) {
        try {
          final ref = FirebaseStorage.instance.ref().child(
            'profile_images/$uid.jpg',
          );
          await ref.putFile(_selectedImage!);
          photoUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Failed to upload image: $e');
        }
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl,
        'aboutMe': _aboutMeController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'age': _ageRange.start.round(),
        'ageRangeStart': _ageRange.start.round(),
        'ageRangeEnd': _ageRange.end.round(),
        'gender': _selectedGender,
        'discoveryModeEnabled': _discoveryModeEnabled,
        'distanceRangeStart': _distanceRange.start.round(),
        'distanceRangeEnd': _distanceRange.end.round(),
        'city': _locationCity,
        'location': _locationCity,
        'networkingCategory': _selectedCategory,
        'networkingSubcategory': _selectedSubcategory,
        'connectionTypes': _selectedConnectionTypes,
        'activities': _selectedActivities,
        'interests': _selectedInterests,
      };

      // Category filters
      if (_categoryFilterValues.isNotEmpty) {
        data['categoryFilters'] = _categoryFilterValues;
      } else {
        data['categoryFilters'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(data);

      // Update Firebase Auth profile
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateProfile(
          displayName: _nameController.text.trim(),
          photoURL: photoUrl,
        );
      }

      if (mounted) {
        _showSnackBar('Profile saved successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        _showSnackBar('Failed to save profile: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) _showSnackBar('Failed to pick image', isError: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo != null && mounted) {
        setState(() => _selectedImage = File(photo.path));
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) _showSnackBar('Failed to take photo', isError: true);
    }
  }

  void _showImagePickerOptions() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 22),
                    const Text(
                      'Change Photo',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF6366F1),
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF06B6D4),
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              if (_selectedImage != null || _currentPhotoUrl != null)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.red),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _currentPhotoUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 46,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
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
          centerTitle: true,
          title: Text(
            'Create Networking Profile',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        bottomNavigationBar: _buildSaveButton(),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(64, 64, 64, 1),
                Color.fromRGBO(40, 40, 40, 1),
                Color.fromRGBO(0, 0, 0, 1),
              ],
              stops: [0.0, 0.45, 0.7, 1.0],
            ),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image with glassmorphic card
                  Center(
                    child: Container(
                      width: 250,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 2,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _selectedImage != null
                                            ? Image.file(
                                                _selectedImage!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              )
                                            : _currentPhotoUrl != null &&
                                                  _currentPhotoUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: _currentPhotoUrl!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white54,
                                                          ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.person_rounded,
                                                          size: 40,
                                                          color: Colors.white54,
                                                        ),
                                              )
                                            : const Icon(
                                                Icons.person_rounded,
                                                size: 40,
                                                color: Colors.white54,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _showImagePickerOptions,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF6366F1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name Field
                  Text(
                    'Name',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    label: '',
                    hint: 'Enter your name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 1. Basic Info Section
                  _buildSectionHeader(
                    'Basic Information',
                    Icons.person_outline_rounded,
                    [const Color(0xFF6366F1), const Color(0xFFA855F7)],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'About Me',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _aboutMeController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length}/300',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: value.text.length > 300
                                  ? Colors.redAccent
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _aboutMeController,
                    label: '',
                    hint: 'Tell others about yourself...',
                    minLines: 1,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Occupation',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _occupationController,
                    label: '',
                    hint: 'e.g. Software Developer, Designer...',
                  ),
                  const SizedBox(height: 16),

                  // 2. Networking Category (Dropdown)
                  _buildSectionHeader(
                    'Networking Category',
                    Icons.hub_rounded,
                    [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                  ),
                  const SizedBox(height: 8),

                  // Category Dropdown
                  LayoutBuilder(
                    builder: (_, boxConstraints) => PopupMenuButton<String>(
                      constraints: BoxConstraints(
                        minWidth: boxConstraints.maxWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      color: const Color(0xFF2A2A2A),
                      position: PopupMenuPosition.under,
                      borderRadius: BorderRadius.circular(14),
                      initialValue: _selectedCategory,
                      itemBuilder: (context) =>
                          _categorySubcategories.keys.map((catName) {
                            final icon =
                                _categoryIcons[catName] ?? Icons.hub_rounded;
                            final colors =
                                _categoryColors[catName] ??
                                [const Color(0xFF6366F1)];
                            return PopupMenuItem<String>(
                              value: catName,
                              child: Row(
                                children: [
                                  Icon(icon, color: colors[0], size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    catName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      onSelected: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedSubcategory = null;
                          _categoryFilterValues.clear();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCategory != null) ...[
                              Icon(
                                _categoryIcons[_selectedCategory] ??
                                    Icons.hub_rounded,
                                color:
                                    (_categoryColors[_selectedCategory] ??
                                    [const Color(0xFF6366F1)])[0],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                _selectedCategory ?? 'Select Category',
                                style: TextStyle(
                                  color: _selectedCategory != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontFamily: 'Poppins',
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

                  // 3. Subcategory Dropdown (if category selected)
                  if (_selectedCategory != null) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final subs =
                            _categorySubcategories[_selectedCategory] ?? [];
                        final catColor =
                            (_categoryColors[_selectedCategory] ??
                            [const Color(0xFF6366F1)])[0];
                        return LayoutBuilder(
                          builder: (_, boxConstraints) =>
                              PopupMenuButton<String>(
                                constraints: BoxConstraints(
                                  minWidth: boxConstraints.maxWidth,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                color: const Color(0xFF2A2A2A),
                                position: PopupMenuPosition.under,
                                borderRadius: BorderRadius.circular(14),
                                initialValue: _selectedSubcategory,
                                itemBuilder: (context) => subs
                                    .map(
                                      (sub) => PopupMenuItem<String>(
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
                                  setState(() {
                                    _selectedSubcategory = value;
                                    _categoryFilterValues.clear();
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.08),
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
                                          _selectedSubcategory ??
                                              'Select Subcategory',
                                          style: TextStyle(
                                            color: _selectedSubcategory != null
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            fontFamily: 'Poppins',
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
                        );
                      },
                    ),

                    // 4. Category + Subcategory specific filter dropdowns
                    for (final filter in <Map<String, dynamic>>[
                      ...(_categoryFilters[_selectedCategory] ?? []),
                      if (_selectedSubcategory != null)
                        ...(_subcategoryFilters[_selectedSubcategory] ?? []),
                    ]) ...[
                      const SizedBox(height: 16),
                      Text(
                        filter['label'] as String,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (_, boxConstraints) {
                          final label = filter['label'] as String;
                          final options = List<String>.from(
                            filter['options'] as List,
                          );
                          final catColor =
                              (_categoryColors[_selectedCategory] ??
                              [const Color(0xFF6366F1)])[0];
                          return PopupMenuButton<String>(
                            constraints: BoxConstraints(
                              minWidth: boxConstraints.maxWidth,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            color: const Color(0xFF2A2A2A),
                            position: PopupMenuPosition.under,
                            borderRadius: BorderRadius.circular(14),
                            initialValue: _categoryFilterValues[label],
                            itemBuilder: (context) => options
                                .map(
                                  (opt) => PopupMenuItem<String>(
                                    value: opt,
                                    child: Text(
                                      opt,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onSelected: (value) {
                              setState(() {
                                _categoryFilterValues[label] = value;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _categoryFilterValues[label] ??
                                          'Select $label',
                                      style: TextStyle(
                                        color:
                                            _categoryFilterValues[label] != null
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
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
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),

                  // ── Age Range (RangeSlider Popup) ──
                  Text(
                    'Age Range',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      RangeValues tempAge = _ageRange;
                      showDialog(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setSliderState) => AlertDialog(
                            backgroundColor: const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
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
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
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
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '18',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
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
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _ageRange = tempAge);
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
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_ageRange.start.round()} - ${_ageRange.end.round() == 60 ? "60+" : _ageRange.end.round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
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
                  const SizedBox(height: 16),

                  // ── Gender (Popup with Icons) ──
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (_, boxConstraints) => PopupMenuButton<String>(
                      constraints: BoxConstraints(
                        minWidth: boxConstraints.maxWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      color: const Color(0xFF2A2A2A),
                      position: PopupMenuPosition.under,
                      borderRadius: BorderRadius.circular(14),
                      initialValue: _selectedGender,
                      itemBuilder: (context) => _genderOptions
                          .map(
                            (gender) => PopupMenuItem<String>(
                              value: gender,
                              child: Row(
                                children: [
                                  Icon(
                                    gender == 'Male'
                                        ? Icons.male
                                        : gender == 'Female'
                                        ? Icons.female
                                        : Icons.transgender,
                                    color: const Color(0xFFFF6B9D),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    gender,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        setState(() => _selectedGender = value);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_selectedGender != null) ...[
                              Icon(
                                _selectedGender == 'Male'
                                    ? Icons.male
                                    : _selectedGender == 'Female'
                                    ? Icons.female
                                    : Icons.transgender,
                                color: const Color(0xFFFF6B9D),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                _selectedGender ?? 'Select Gender',
                                style: TextStyle(
                                  color: _selectedGender != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontFamily: 'Poppins',
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
                  const SizedBox(height: 16),

                  // ── Location (Distance RangeSlider Popup) ──
                  Text(
                    'Location',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      RangeValues tempDist = _distanceRange;
                      showDialog(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setSliderState) => AlertDialog(
                            backgroundColor: const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
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
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withValues(
                                      alpha: 0.1,
                                    ),
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
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '1 km',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
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
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _distanceRange = tempDist);
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
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_distanceRange.start.round()} km - ${_distanceRange.end.round() == 500 ? "500+" : "${_distanceRange.end.round()}"} km',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
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
                  const SizedBox(height: 16),

                  // ── Active Status (Discovery Toggle) ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _discoveryModeEnabled
                                ? const Color(0xFF00E676)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow: _discoveryModeEnabled
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
                        const Expanded(
                          child: Text(
                            'Show me in Discovery',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          width: 40,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Switch(
                              value: _discoveryModeEnabled,
                              onChanged: (value) {
                                setState(() => _discoveryModeEnabled = value);
                              },
                              activeTrackColor: const Color(
                                0xFF00E676,
                              ).withValues(alpha: 0.5),
                              activeThumbColor: const Color(0xFF00E676),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Section Header ────────────────────
  Widget _buildSectionHeader(String title, IconData icon, List<Color> colors) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  // ──────────────────── Text Field ────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        keyboardType: minLines != null ? TextInputType.multiline : keyboardType,
        textAlignVertical: TextAlignVertical.top,
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label.isNotEmpty ? label : null,
          hintText: hint,
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          counterStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ──────────────────── Save Button ────────────────────
  Widget _buildSaveButton() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(30, 30, 30, 1),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF016CFF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF016CFF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Save Profile',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
