import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_networking_profile_screen.dart';
import 'edit_networking_profile_screen.dart';

class MyNetworkingProfileScreen extends StatefulWidget {
  const MyNetworkingProfileScreen({super.key});

  @override
  State<MyNetworkingProfileScreen> createState() =>
      _MyNetworkingProfileScreenState();
}

class _MyNetworkingProfileScreenState extends State<MyNetworkingProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _profileData = doc.data();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateNetworkingProfileScreen(),
      ),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      _loadProfile();
    }
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditNetworkingProfileScreen(),
      ),
    );
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      _loadProfile();
    }
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
          title: const Text(
            'My Networking Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: const [],
        ),
        bottomNavigationBar: _buildEditButton(),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                )
              : _profileData == null
                  ? _buildEmptyState()
                  : _buildProfileContent(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'No Profile Yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your networking profile to start connecting with people.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _navigateToCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF016CFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Create Profile',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    final data = _profileData!;
    final name = data['name'] as String? ?? '';
    final photoUrl = data['photoUrl'] as String?;
    final aboutMe = data['aboutMe'] as String? ?? '';
    final occupation = data['occupation'] as String? ?? '';
    final gender = data['gender'] as String?;
    final category = data['networkingCategory'] as String?;
    final subcategory = data['networkingSubcategory'] as String?;
    final ageStart = data['ageRangeStart'] as num?;
    final ageEnd = data['ageRangeEnd'] as num?;
    final distStart = data['distanceRangeStart'] as num?;
    final distEnd = data['distanceRangeEnd'] as num?;
    final discoveryEnabled = data['discoveryModeEnabled'] ?? true;
    final city = data['city'] as String? ?? data['location'] as String?;
    final categoryFilters =
        data['categoryFilters'] != null
            ? Map<String, String>.from(data['categoryFilters'])
            : <String, String>{};

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image + Name - Glassmorphic Card
          Container(
            width: double.infinity,
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
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2,
                          ),
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
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
                      const SizedBox(height: 14),
                      Text(
                        name.isNotEmpty ? name : 'No Name',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        occupation.isNotEmpty ? occupation : 'No Occupation',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Discovery Status
          _buildInfoCard(
            icon: Icons.circle,
            iconColor: discoveryEnabled
                ? const Color(0xFF00E676)
                : Colors.grey,
            iconSize: 10,
            label: discoveryEnabled
                ? 'Visible in Discovery'
                : 'Hidden from Discovery',
          ),
          const SizedBox(height: 16),

          // About Me
          _buildSectionTitle('About Me'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              aboutMe.isNotEmpty ? aboutMe : 'Not set',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: aboutMe.isNotEmpty
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Networking Category
          _buildSectionTitle('Networking Category'),
          const SizedBox(height: 8),
          if (category != null)
            _buildCategoryBadge(category, subcategory)
          else
            _buildDetailRow('Category', 'Not selected'),
          const SizedBox(height: 16),

          // Category Filters
          if (categoryFilters.isNotEmpty) ...[
            _buildSectionTitle('Profile Details'),
            const SizedBox(height: 8),
            ...categoryFilters.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildDetailRow(e.key, e.value),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Basic Info Grid
          _buildSectionTitle('Basic Information'),
          const SizedBox(height: 8),
          _buildDetailRow('Gender', gender ?? 'Not set'),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Age Range',
            ageStart != null && ageEnd != null
                ? '${ageStart.round()} - ${ageEnd.round() == 60 ? "60+" : ageEnd.round()}'
                : 'Not set',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Distance',
            distStart != null && distEnd != null
                ? '${distStart.round()} km - ${distEnd.round() == 500 ? "500+" : "${distEnd.round()}"} km'
                : 'Not set',
          ),
          const SizedBox(height: 8),
          _buildDetailRow('City', city != null && city.isNotEmpty ? city : 'Not set'),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
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

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    double iconSize = 18,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category, String? subcategory) {
    final colors = _categoryColors[category] ??
        [const Color(0xFF6366F1), const Color(0xFF818CF8)];
    final icon = _categoryIcons[category] ?? Icons.hub_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors[0].withValues(alpha: 0.2),
            colors[1].withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors[0].withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors[0], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors[0],
                  ),
                ),
                if (subcategory != null && subcategory.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subcategory,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: colors[0].withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
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
            onTap: _navigateToEdit,
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
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Edit Profile',
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
        ),
      ),
    );
  }

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
}
