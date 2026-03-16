import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_networking_profile_screen.dart';
import 'edit_networking_profile_screen.dart';
import '../../widgets/networking/networking_widgets.dart';

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
      // Try networking_profiles first
      final netDoc = await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .get();
      if (netDoc.exists && netDoc.data() != null && mounted) {
        setState(() {
          _profileData = netDoc.data();
          _isLoading = false;
        });
        return;
      }

      // Fallback to users collection for legacy profiles
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists && userDoc.data() != null && mounted) {
        setState(() {
          _profileData = userDoc.data();
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
        builder: (_) => const CreateNetworkingProfileScreen(
          createdFrom: 'My Profile',
        ),
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
        appBar: NetworkingWidgets.networkingAppBar(
          title: 'My Networking Profile',
          onBack: () => Navigator.pop(context),
        ),
        bottomNavigationBar: _profileData != null
            ? NetworkingWidgets.bottomActionButton(
                context: context,
                label: 'Edit Profile',
                icon: Icons.edit_rounded,
                isLoading: false,
                onTap: _navigateToEdit,
              )
            : null,
        body: Container(
          decoration: NetworkingWidgets.bodyGradient(fourStop: true),
          child: _isLoading
              ? NetworkingWidgets.loadingIndicator()
              : _profileData == null
                  ? _buildEmptyState()
                  : _buildProfileContent(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return NetworkingWidgets.emptyState(
      icon: Icons.person_outline_rounded,
      title: 'No Profile Yet',
      message: 'Create your networking profile to start connecting with people.',
      buttonLabel: 'Create Profile',
      onButtonTap: _navigateToCreate,
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
    final dateOfBirth = data['dateOfBirth'] as String?;
    final discoveryEnabled = data['discoveryModeEnabled'] ?? true;
    final rawCity = data['city'] as String? ?? data['location'] as String? ?? '';
    final city = rawCity.toLowerCase().contains('mountain view') ? '' : rawCity;
    final categoryFilters = data['categoryFilters'] is Map
        ? (data['categoryFilters'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
        : <String, String>{};

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image + Name - Glassmorphic Card
          NetworkingWidgets.profileAvatarCard(
            name: name,
            photoUrl: photoUrl,
            subtitle: occupation.isNotEmpty ? occupation : 'No Occupation',
          ),
          const SizedBox(height: 20),

          // Discovery Status
          NetworkingWidgets.infoCard(
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
          NetworkingWidgets.sectionTitle('About Me'),
          const SizedBox(height: 8),
          NetworkingWidgets.textCard(aboutMe),
          const SizedBox(height: 16),

          // Networking Category
          NetworkingWidgets.sectionTitle('Networking Category'),
          const SizedBox(height: 8),
          if (category != null)
            NetworkingWidgets.categoryBadge(category, subcategory)
          else
            NetworkingWidgets.detailRow('Category', 'Not selected'),
          const SizedBox(height: 16),

          // Category Filters
          if (categoryFilters.isNotEmpty) ...[
            NetworkingWidgets.sectionTitle('Profile Details'),
            const SizedBox(height: 8),
            ...categoryFilters.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NetworkingWidgets.detailRow(e.key, e.value),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Basic Info Grid
          NetworkingWidgets.sectionTitle('Basic Information'),
          const SizedBox(height: 8),
          NetworkingWidgets.detailRow('Gender', gender ?? 'Not set'),
          const SizedBox(height: 8),
          NetworkingWidgets.detailRow(
            'Date of Birth',
            dateOfBirth != null && dateOfBirth.isNotEmpty
                ? (() {
                    final parts = dateOfBirth.split('-');
                    if (parts.length == 3) {
                      return '${parts[2]}/${parts[1]}/${parts[0]}';
                    }
                    return dateOfBirth;
                  })()
                : 'Not set',
          ),
          const SizedBox(height: 8),
          NetworkingWidgets.detailRow('Location', city.isNotEmpty ? city : 'Not set'),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

}
