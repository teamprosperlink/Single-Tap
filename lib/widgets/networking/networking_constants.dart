import 'package:flutter/material.dart';

/// Shared constants for all networking screens.
/// Single source of truth for category data, icons, colors, and filters.
class NetworkingConstants {
  NetworkingConstants._();

  // ── Gender options ──
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Other',
  ];

  // ── Categories → Subcategories ──
  static const Map<String, List<String>> categorySubcategories = {
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

  // ── Category icons (rounded) ──
  static const Map<String, IconData> categoryIcons = {
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

  // ── Category gradient colors (for profile badges, cards) ──
  static const Map<String, List<Color>> categoryColors = {
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

  // ── Flat icons (non-rounded, used in Live Connect tab chips) ──
  static const Map<String, IconData> categoryFlatIcons = {
    'Professional': Icons.business_center,
    'Business': Icons.storefront,
    'Social': Icons.groups,
    'Educational': Icons.school,
    'Creative': Icons.palette,
    'Tech': Icons.computer,
    'Industry': Icons.factory,
    'Investment & Finance': Icons.account_balance,
    'Event & Meetup': Icons.event,
    'Community': Icons.volunteer_activism,
    'Personal Development': Icons.self_improvement,
    'Global / NRI': Icons.public,
  };

  // ── Flat colors (single color, used in Live Connect tab chips) ──
  static const Map<String, Color> categoryFlatColors = {
    'Professional': Color(0xFF2196F3),
    'Business': Color(0xFFFFA502),
    'Social': Color(0xFF00D2D3),
    'Educational': Color(0xFFFF6348),
    'Creative': Color(0xFFFF9100),
    'Tech': Color(0xFF7C4DFF),
    'Industry': Color(0xFF78909C),
    'Investment & Finance': Color(0xFF4CAF50),
    'Event & Meetup': Color(0xFFE040FB),
    'Community': Color(0xFFFF6B81),
    'Personal Development': Color(0xFF00E676),
    'Global / NRI': Color(0xFF1E90FF),
  };

  // ── Category → connection type groups (Live Connect) ──
  static const Map<String, List<String>> categoryConnectionGroups = {
    'Professional': [],
    'Business': [],
    'Social': ['Social', 'Other'],
    'Educational': ['Educational'],
    'Creative': ['Creative'],
    'Tech': [],
    'Industry': [],
    'Investment & Finance': [],
    'Event & Meetup': [],
    'Community': ['Community'],
    'Personal Development': [],
    'Global / NRI': [],
  };

  // ── Category → activity groups (Live Connect) ──
  static const Map<String, List<String>> categoryActivityGroups = {
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

  // ── Category-specific filters ──
  static const Map<String, List<Map<String, dynamic>>> categoryFilters = {
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

  // ── Subcategory-Specific Filters ──
  static const Map<String, List<Map<String, dynamic>>> subcategoryFilters = {
    // Professional
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
    // Business
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
    // Social
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
    // Educational
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
    // Creative
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
    // Tech
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
    // Industry
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
    // Investment & Finance
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
    // Event & Meetup
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
    // Community
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
    // Personal Development
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
    // Global / NRI
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

  // ── Helpers ──

  /// Get gradient color pair for a category, with fallback.
  static List<Color> getCategoryColors(String? category) {
    return categoryColors[category] ??
        const [Color(0xFF6366F1), Color(0xFF818CF8)];
  }

  /// Get icon for a category (rounded variant), with fallback.
  static IconData getCategoryIcon(String? category) {
    return categoryIcons[category] ?? Icons.hub_rounded;
  }

  /// Get flat color for a category (Live Connect variant), with fallback.
  static Color getCategoryFlatColor(String? category) {
    return categoryFlatColors[category] ?? const Color(0xFF2196F3);
  }
}
