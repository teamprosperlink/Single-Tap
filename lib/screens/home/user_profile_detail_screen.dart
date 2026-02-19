import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/extended_user_profile.dart';
import '../../models/user_profile.dart';
import '../../res/config/app_text_styles.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../services/connection_service.dart';
import '../chat/enhanced_chat_screen.dart';

class UserProfileDetailScreen extends StatefulWidget {
  final ExtendedUserProfile user;
  final String? connectionStatus; // 'connected', 'sent', 'received', or null
  final Future<void> Function()? onConnect;
  final String?
  selectedCategory; // Category selected in networking screen filter
  final String?
  selectedSubcategory; // Subcategory selected in networking screen filter

  const UserProfileDetailScreen({
    super.key,
    required this.user,
    this.connectionStatus,
    this.onConnect,
    this.selectedCategory,
    this.selectedSubcategory,
  });

  @override
  State<UserProfileDetailScreen> createState() =>
      _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShowTitle = offset > 250;

    if (shouldShowTitle != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = shouldShowTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final user = widget.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color.fromRGBO(0, 0, 0, 1),
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
          title: const Text(
            'Profile Details',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomActions(context, user),
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
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image
                SizedBox(
                  height: screenHeight * 0.45,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildHeroImage(user, screenWidth),

                      // Gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: screenHeight * 0.25,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color.fromRGBO(
                                  64,
                                  64,
                                  64,
                                  1,
                                ).withValues(alpha: 0.3),
                                const Color.fromRGBO(
                                  64,
                                  64,
                                  64,
                                  1,
                                ).withValues(alpha: 0.7),
                                const Color.fromRGBO(64, 64, 64, 1),
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Name & info at bottom of image
                      Positioned(
                        bottom: 16,
                        left: 20,
                        right: 20,
                        child: FadeTransition(
                          opacity: _fadeController,
                          child: _buildNameSection(user),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content sections
                FadeTransition(
                  opacity: _fadeController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Quick info cards row
                        _buildQuickInfoRow(user),
                        const SizedBox(height: 24),

                        // Networking category sections
                        ..._buildAllNetworkingSections(user),

                        // About section
                        if (user.aboutMe != null &&
                            user.aboutMe!.isNotEmpty) ...[
                          _buildAboutSection(user),
                          const SizedBox(height: 24),
                        ],

                        // Connection Types
                        if (user.connectionTypes.isNotEmpty) ...[
                          _buildSectionTitle('Looking For'),
                          const SizedBox(height: 12),
                          _buildConnectionTypeChips(user.connectionTypes),
                          const SizedBox(height: 24),
                        ],

                        // Activities
                        if (user.activities.isNotEmpty) ...[
                          _buildSectionTitle('Activities'),
                          const SizedBox(height: 12),
                          _buildActivityChips(
                            user.activities.map((a) => a.name).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Interests
                        if (user.interests.isNotEmpty) ...[
                          _buildSectionTitle('Interests'),
                          const SizedBox(height: 12),
                          _buildInterestChips(user.interests),
                          const SizedBox(height: 24),
                        ],

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(ExtendedUserProfile user, double screenWidth) {
    // Support asset images (e.g. 'assets/images/abdulla.jpeg')
    if (user.photoUrl != null && user.photoUrl!.startsWith('assets/')) {
      return SizedBox.expand(
        child: Image.asset(
          user.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Asset load error: $error');
            return Container(
              color: Colors.grey.shade800,
              child: const Center(
                child: Icon(Icons.person, size: 80, color: Colors.white54),
              ),
            );
          },
        ),
      );
    }

    final isValidPhoto = PhotoUrlHelper.isValidUrl(user.photoUrl);
    final fixedUrl = PhotoUrlHelper.fixGooglePhotoUrl(user.photoUrl);
    final isGooglePhoto =
        fixedUrl != null && fixedUrl.contains('googleusercontent.com');

    if (isValidPhoto && fixedUrl != null) {
      return CachedNetworkImage(
        imageUrl: fixedUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderAvatar(user),
        errorWidget: (context, url, error) => _buildPlaceholderAvatar(user),
        imageBuilder: (context, imageProvider) {
          final child = SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            ),
          );
          if (isGooglePhoto) {
            return ClipRect(child: Transform.scale(scale: 1.5, child: child));
          }
          return child;
        },
      );
    }
    return _buildPlaceholderAvatar(user);
  }

  Widget _buildPlaceholderAvatar(ExtendedUserProfile user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1),
            const Color(0xFF8B5CF6),
            const Color(0xFFA855F7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildNameSection(ExtendedUserProfile user) {
    final firstName = user.name.split(' ').first;
    final nameWithAge = user.age != null
        ? '$firstName, ${user.age}'
        : firstName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + verified
        Row(
          children: [
            Flexible(
              child: Text(
                nameWithAge,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
            ),
            if (user.verified) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ],
            const SizedBox(width: 10),
            // Online indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: user.isOnline
                    ? const Color(0xFF00E676)
                    : Colors.grey.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: user.isOnline
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E676).withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
        // Occupation / profession
        if (user.occupation != null && user.occupation!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            user.occupation!,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
        const SizedBox(height: 6),

        // Location + distance row
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              user.displayLocation,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (user.formattedDistance != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                user.formattedDistance!,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuickInfoRow(ExtendedUserProfile user) {
    final items = <_InfoItem>[];

    if (user.gender != null && user.gender!.isNotEmpty) {
      items.add(
        _InfoItem(
          icon: user.gender == 'Male'
              ? Icons.male_rounded
              : user.gender == 'Female'
              ? Icons.female_rounded
              : Icons.transgender_rounded,
          label: user.gender!,
          gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      );
    }

    if (user.connectionCount > 0) {
      items.add(
        _InfoItem(
          icon: Icons.people_rounded,
          label: '${user.connectionCount} Connections',
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        ),
      );
    }

    if (user.category != null && user.category!.isNotEmpty) {
      items.add(
        _InfoItem(
          icon: Icons.work_rounded,
          label: user.category!,
          gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
      );
    }

    if (user.businessName != null && user.businessName!.isNotEmpty) {
      items.add(
        _InfoItem(
          icon: Icons.business_rounded,
          label: user.businessName!,
          gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
      );
    }

    // Account type badge
    if (user.isProfessional) {
      items.add(
        const _InfoItem(
          icon: Icons.verified_user_rounded,
          label: 'Professional',
          gradient: [Color(0xFFA855F7), Color(0xFFC084FC)],
        ),
      );
    } else if (user.isBusiness) {
      items.add(
        const _InfoItem(
          icon: Icons.storefront_rounded,
          label: 'Business',
          gradient: [Color(0xFFF97316), Color(0xFFFB923C)],
        ),
      );
    }

    // Last seen
    if (!user.isOnline && user.lastSeen != null) {
      final lastSeenTime = user.lastSeen!.toDate();
      final diff = DateTime.now().difference(lastSeenTime);
      String lastSeenText;
      if (diff.inMinutes < 60) {
        lastSeenText = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        lastSeenText = '${diff.inHours}h ago';
      } else {
        lastSeenText = '${diff.inDays}d ago';
      }
      items.add(
        _InfoItem(
          icon: Icons.access_time_rounded,
          label: 'Active $lastSeenText',
          gradient: const [Color(0xFF8E8E93), Color(0xFFAEAEB2)],
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item.gradient[0].withValues(alpha: 0.25),
                  item.gradient[1].withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: item.gradient[0].withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 18, color: item.gradient[0]),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: item.gradient[0],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Networking category data (categories → subcategories) ──
  static const Map<String, List<String>> _networkingCategorySubcategories = {
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

  // ── Category-specific filter labels (what details each category can have) ──
  static const Map<String, List<String>> _categoryFilterLabels = {
    'Professional': [
      'Experience Level',
      'Employment Type',
      'Work Mode',
      'Industry',
    ],
    'Business': [
      'Business Stage',
      'Company Size',
      'Business Model',
      'Industry Sector',
    ],
    'Social': ['Availability', 'Interests', 'Vibe'],
    'Educational': ['Skill Level', 'Format', 'Subject', 'Language'],
    'Creative': ['Skill Level', 'Collaboration', 'Portfolio'],
    'Tech': ['Experience Level', 'Tech Stack', 'Purpose'],
    'Industry': [
      'Business Role',
      'Company Size',
      'Trade Type',
      'Certifications',
    ],
    'Investment & Finance': [
      'Experience',
      'Risk Appetite',
      'Investment Horizon',
      'Purpose',
    ],
    'Event & Meetup': ['Event Format', 'When', 'Time of Day', 'Price'],
    'Community': ['Involvement', 'Commitment', 'Cause Area', 'Skills Offered'],
    'Personal Development': ['Level', 'Format', 'Session Duration', 'Goal'],
    'Global / NRI': ['Destination', 'Service Type', 'Urgency', 'Language'],
  };

  /// Maps user occupation to the most relevant networking category
  String? _deriveFromOccupation(String? occupation) {
    if (occupation == null || occupation.isEmpty) return null;
    final occ = occupation.toLowerCase().trim();

    // Educational
    if (occ.contains('student') ||
        occ.contains('teacher') ||
        occ.contains('professor') ||
        occ.contains('tutor') ||
        occ.contains('researcher') ||
        occ.contains('scholar') ||
        occ.contains('lecturer') ||
        occ.contains('instructor') ||
        occ.contains('academic') ||
        occ.contains('phd')) {
      return 'Educational';
    }
    // Tech
    if (occ.contains('developer') ||
        occ.contains('engineer') ||
        occ.contains('programmer') ||
        occ.contains('software') ||
        occ.contains('data scientist') ||
        occ.contains('devops') ||
        occ.contains('cyber') ||
        occ.contains('it ') ||
        occ.contains('full stack') ||
        occ.contains('frontend') ||
        occ.contains('backend') ||
        occ.contains('cloud') ||
        occ.contains('ai ') ||
        occ.contains('machine learning')) {
      return 'Tech';
    }
    // Creative
    if (occ.contains('designer') ||
        occ.contains('artist') ||
        occ.contains('photographer') ||
        occ.contains('musician') ||
        occ.contains('writer') ||
        occ.contains('filmmaker') ||
        occ.contains('animator') ||
        occ.contains('content creator') ||
        occ.contains('illustrator') ||
        occ.contains('editor') ||
        occ.contains('videographer') ||
        occ.contains('dj') ||
        occ.contains('dancer') ||
        occ.contains('model') ||
        occ.contains('actor') ||
        occ.contains('singer') ||
        occ.contains('choreographer') ||
        occ.contains('painter')) {
      return 'Creative';
    }
    // Business
    if (occ.contains('founder') ||
        occ.contains('ceo') ||
        occ.contains('entrepreneur') ||
        occ.contains('business owner') ||
        occ.contains('retailer') ||
        occ.contains('coo') ||
        occ.contains('cto') ||
        occ.contains('startup')) {
      return 'Business';
    }
    // Investment & Finance
    if (occ.contains('investor') ||
        occ.contains('finance') ||
        occ.contains('banker') ||
        occ.contains('accountant') ||
        occ.contains('trader') ||
        occ.contains('financial') ||
        occ.contains('ca ') ||
        occ.contains('chartered')) {
      return 'Investment & Finance';
    }
    // Industry
    if (occ.contains('manufactur') ||
        occ.contains('factory') ||
        occ.contains('logistics') ||
        occ.contains('construction') ||
        occ.contains('agriculture') ||
        occ.contains('mining') ||
        occ.contains('pharma') ||
        occ.contains('automotive')) {
      return 'Industry';
    }
    // Community
    if (occ.contains('volunteer') ||
        occ.contains('ngo') ||
        occ.contains('social worker') ||
        occ.contains('nonprofit') ||
        occ.contains('activist') ||
        occ.contains('charity')) {
      return 'Community';
    }
    // Personal Development
    if (occ.contains('coach') ||
        occ.contains('trainer') ||
        occ.contains('yoga') ||
        occ.contains('fitness') ||
        occ.contains('wellness') ||
        occ.contains('motivational') ||
        occ.contains('life coach') ||
        occ.contains('nutritionist')) {
      return 'Personal Development';
    }
    // Professional (catch-all for office/corporate roles)
    if (occ.contains('manager') ||
        occ.contains('consultant') ||
        occ.contains('analyst') ||
        occ.contains('recruiter') ||
        occ.contains('freelancer') ||
        occ.contains('executive') ||
        occ.contains('director') ||
        occ.contains('coordinator') ||
        occ.contains('lawyer') ||
        occ.contains('doctor') ||
        occ.contains('nurse') ||
        occ.contains('architect') ||
        occ.contains('marketing') ||
        occ.contains('sales') ||
        occ.contains('hr ') ||
        occ.contains('human resource') ||
        occ.contains('chef') ||
        occ.contains('pilot') ||
        occ.contains('journalist') ||
        occ.contains('pharmacist')) {
      return 'Professional';
    }

    return null;
  }

  /// Builds all networking sections based on:
  /// 1. Selected category/subcategory from networking screen filter (highest priority)
  /// 2. User's explicit networkingCategory from Firestore
  /// 3. Derived from user interests
  List<Widget> _buildAllNetworkingSections(ExtendedUserProfile user) {
    // Determine the category to show
    String? category;
    String? subcategory;

    // Priority 1: Selected category from networking screen filter
    if (widget.selectedCategory != null &&
        widget.selectedCategory!.isNotEmpty &&
        widget.selectedCategory != 'All') {
      category = widget.selectedCategory;
      subcategory = widget.selectedSubcategory;
    }
    // Priority 2: User's explicit networking category from Firestore
    else if (user.networkingCategory != null &&
        user.networkingCategory!.isNotEmpty) {
      category = user.networkingCategory;
      subcategory = user.networkingSubcategory;
    }
    // Priority 3: Derive from user's occupation first, then interests
    else {
      // 3a: Map occupation to networking category
      category = _deriveFromOccupation(user.occupation);

      // 3b: Fall back to interests if occupation didn't match
      if (category == null) {
        for (final interest in user.interests) {
          if (_networkingCategorySubcategories.containsKey(interest)) {
            category = interest;
            break;
          }
          for (final entry in _networkingCategorySubcategories.entries) {
            if (entry.value.any(
              (sub) => sub.toLowerCase() == interest.toLowerCase(),
            )) {
              category = entry.key;
              subcategory = entry.value.firstWhere(
                (sub) => sub.toLowerCase() == interest.toLowerCase(),
                orElse: () => '',
              );
              break;
            }
          }
          if (category != null) break;
        }
      }
    }

    if (category == null) return [];

    final widgets = <Widget>[];
    final subs = _networkingCategorySubcategories[category] ?? [];

    // Category badge
    widgets.add(_buildNetworkingBadge(category));
    widgets.add(const SizedBox(height: 16));

    // Subcategory badge (if selected or from user data)
    if (subcategory != null && subcategory.isNotEmpty) {
      widgets.add(_buildSubcategoryBadge(category, subcategory));
      widgets.add(const SizedBox(height: 16));
    }

    // Category-specific details from Firestore (if user has them)
    if (user.categoryFilters.isNotEmpty) {
      widgets.add(_buildCategoryDetailsCard(category, user.categoryFilters));
      widgets.add(const SizedBox(height: 24));
    } else {
      // Show subcategories for this category
      if (subs.isNotEmpty) {
        widgets.add(_buildSectionTitle('$category Subcategories'));
        widgets.add(const SizedBox(height: 12));
        widgets.add(_buildSubcategoryChips(category, subs));
        widgets.add(const SizedBox(height: 16));
      }

      // Show category attributes
      final filterLabels = _categoryFilterLabels[category];
      if (filterLabels != null && filterLabels.isNotEmpty) {
        widgets.add(_buildCategoryFilterLabelsCard(category, filterLabels));
        widgets.add(const SizedBox(height: 24));
      }
    }

    return widgets;
  }

  Widget _buildSubcategoryChips(String category, List<String> subcategories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subcategories.map((sub) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryFilterLabelsCard(
    String category,
    List<String> filterLabels,
  ) {
    final catColors = _getCategoryColors(category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        LinearGradient(colors: catColors).createShader(bounds),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$category Attributes',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filterLabels.map((label) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkingBadge(String category) {
    final catIcons = <String, IconData>{
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

    final colors = _getCategoryColors(category);
    final icon = catIcons[category] ?? Icons.hub_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$category Networking',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Active in this networking category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildSubcategoryBadge(String category, String subcategory) {
    final catColors = _getCategoryColors(category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: catColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.label_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subcategory',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subcategory,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildCategoryDetailsCard(
    String category,
    Map<String, String> filters,
  ) {
    final catColors = _getCategoryColors(category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        LinearGradient(colors: catColors).createShader(bounds),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$category Details',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...filters.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
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
      ),
    );
  }

  List<Color> _getCategoryColors(String category) {
    final catColors = <String, List<Color>>{
      'Professional': [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      'Business': [const Color(0xFF10B981), const Color(0xFF34D399)],
      'Social': [const Color(0xFFEC4899), const Color(0xFFF472B6)],
      'Educational': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      'Creative': [const Color(0xFFA855F7), const Color(0xFFC084FC)],
      'Tech': [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      'Industry': [const Color(0xFFF97316), const Color(0xFFFB923C)],
      'Investment & Finance': [
        const Color(0xFF14B8A6),
        const Color(0xFF2DD4BF),
      ],
      'Event & Meetup': [const Color(0xFFEF4444), const Color(0xFFF87171)],
      'Community': [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      'Personal Development': [
        const Color(0xFF06B6D4),
        const Color(0xFF22D3EE),
      ],
      'Global / NRI': [const Color(0xFFD946EF), const Color(0xFFE879F9)],
    };
    return catColors[category] ??
        [const Color(0xFF6366F1), const Color(0xFF818CF8)];
  }

  Widget _buildAboutSection(ExtendedUserProfile user) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'About',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user.aboutMe!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionTypeChips(List<String> types) {
    final gradients = <String, List<Color>>{
      'Dating': [const Color(0xFFFF4444), const Color(0xFFFF6B6B)],
      'Friendship': [const Color(0xFFFF6B9D), const Color(0xFFFF8FC4)],
      'Networking': [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      'Business Partner': [const Color(0xFF10B981), const Color(0xFF34D399)],
      'Mentorship': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      'Travel Buddy': [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      'Casual Hangout': [const Color(0xFFA855F7), const Color(0xFFC084FC)],
    };

    return _buildChipWrap(types, (type, index) {
      final colors =
          gradients[type] ?? [const Color(0xFF6366F1), const Color(0xFF818CF8)];
      return _buildGradientChip(type, colors, _getConnectionIcon(type));
    });
  }

  Widget _buildActivityChips(List<String> activities) {
    return _buildChipWrap(activities, (activity, index) {
      final colors = _getActivityColors(index);
      return _buildGradientChip(activity, colors, _getActivityIcon(activity));
    });
  }

  Widget _buildInterestChips(List<String> interests) {
    return _buildChipWrap(interests, (interest, index) {
      final colors = _getInterestColors(index);
      return _buildGradientChip(interest, colors, null);
    });
  }

  Widget _buildChipWrap(
    List<String> items,
    Widget Function(String item, int index) builder,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .asMap()
          .entries
          .map((e) => builder(e.value, e.key))
          .toList(),
    );
  }

  Widget _buildGradientChip(String label, List<Color> colors, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, ExtendedUserProfile user) {
    final isConnected = widget.connectionStatus == 'connected';
    final isRequestSent = widget.connectionStatus == 'sent';
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
          child: Row(
            children: [
              // State 1: Not connected, no request sent → Show Connect button only
              if (!isConnected && !isRequestSent)
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (widget.onConnect != null) {
                        await widget.onConnect!();
                        if (mounted) Navigator.pop(context);
                      } else {
                        // Send connection request directly
                        final result = await ConnectionService()
                            .sendConnectionRequest(receiverId: widget.user.uid);
                        if (!mounted) return;
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connection request sent!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] ?? 'Failed to send request',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF016CFF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF016CFF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Connect',
                            style: TextStyle(
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

              // State 2: Request sent → Show Request Sent button only (no chat)
              if (isRequestSent)
                Expanded(
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Request Sent',
                          style: TextStyle(
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

              // State 3: Connected → Show Message button only
              if (isConnected)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openChat(user),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF016CFF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF016CFF,
                            ).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Message',
                            style: TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(ExtendedUserProfile user) {
    final userProfile = UserProfile(
      uid: user.uid,
      name: user.name,
      email: '',
      profileImageUrl: user.photoUrl,
      location: user.location,
      latitude: user.latitude,
      longitude: user.longitude,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: user.isOnline,
      interests: user.interests,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedChatScreen(otherUser: userProfile),
      ),
    );
  }

  // Helper methods for icons and colors
  IconData _getConnectionIcon(String type) {
    switch (type) {
      case 'Dating':
        return Icons.favorite_rounded;
      case 'Friendship':
        return Icons.emoji_emotions_rounded;
      case 'Networking':
        return Icons.handshake_rounded;
      case 'Business Partner':
        return Icons.business_center_rounded;
      case 'Mentorship':
        return Icons.school_rounded;
      case 'Travel Buddy':
        return Icons.flight_rounded;
      case 'Casual Hangout':
        return Icons.local_cafe_rounded;
      case 'Nightlife Partner':
        return Icons.nightlife_rounded;
      case 'Workout Partner':
        return Icons.fitness_center_rounded;
      case 'Sports Partner':
        return Icons.sports_tennis_rounded;
      case 'Career Advice':
        return Icons.trending_up_rounded;
      case 'Collaboration':
        return Icons.group_work_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'tennis':
      case 'badminton':
      case 'squash':
        return Icons.sports_tennis_rounded;
      case 'basketball':
        return Icons.sports_basketball_rounded;
      case 'football':
        return Icons.sports_soccer_rounded;
      case 'running':
        return Icons.directions_run_rounded;
      case 'gym':
      case 'crossfit':
        return Icons.fitness_center_rounded;
      case 'yoga':
      case 'pilates':
        return Icons.self_improvement_rounded;
      case 'cycling':
        return Icons.pedal_bike_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'hiking':
        return Icons.terrain_rounded;
      case 'photography':
        return Icons.camera_alt_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'cooking':
        return Icons.restaurant_rounded;
      case 'gaming':
        return Icons.sports_esports_rounded;
      case 'dance':
        return Icons.nightlife_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  List<Color> _getActivityColors(int index) {
    final palettes = [
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      [const Color(0xFFF97316), const Color(0xFFFB923C)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFEF4444), const Color(0xFFF87171)],
      [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
    ];
    return palettes[index % palettes.length];
  }

  List<Color> _getInterestColors(int index) {
    final palettes = [
      [const Color(0xFFEC4899), const Color(0xFFF472B6)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFF6366F1), const Color(0xFF818CF8)],
      [const Color(0xFFF97316), const Color(0xFFFB923C)],
    ];
    return palettes[index % palettes.length];
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final List<Color> gradient;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.gradient,
  });
}
