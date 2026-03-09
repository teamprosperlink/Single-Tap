import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../widgets/networking/networking_constants.dart';
import '../../widgets/networking/networking_helpers.dart';
import '../../widgets/networking/networking_widgets.dart';

class NetworkingProfilesPageScreen extends StatefulWidget {
  const NetworkingProfilesPageScreen({super.key});

  @override
  State<NetworkingProfilesPageScreen> createState() =>
      _NetworkingProfilesPageScreenState();
}

class _NetworkingProfilesPageScreenState
    extends State<NetworkingProfilesPageScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserLocation();
    _loadProfiles();
  }

  Future<void> _loadCurrentUserLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        _myLat = (doc.data()!['latitude'] as num?)?.toDouble();
        _myLng = (doc.data()!['longitude'] as num?)?.toDouble();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _loadProfiles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      List<Map<String, dynamic>> profiles = [];

      // Query subcollection for all profiles (no orderBy to avoid index issues)
      final snapshot = await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .collection('profiles')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final seenIds = <String>{};
        for (final doc in snapshot.docs) {
          // Deduplicate by doc.id
          if (!seenIds.add(doc.id)) continue;
          profiles.add(doc.data());
        }
      } else {
        // Migration: if subcollection is empty, check top-level doc
        final topDoc = await FirebaseFirestore.instance
            .collection('networking_profiles')
            .doc(uid)
            .get();
        if (topDoc.exists && topDoc.data() != null) {
          profiles.add(topDoc.data()!);
          // Copy to subcollection (non-fatal if fails)
          try {
            final data = Map<String, dynamic>.from(topDoc.data()!);
            data['createdAt'] = FieldValue.serverTimestamp();
            await FirebaseFirestore.instance
                .collection('networking_profiles')
                .doc(uid)
                .collection('profiles')
                .add(data);
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading networking profiles: $e');
      // Fallback: try loading top-level doc directly
      try {
        final topDoc = await FirebaseFirestore.instance
            .collection('networking_profiles')
            .doc(uid)
            .get();
        if (topDoc.exists && topDoc.data() != null && mounted) {
          setState(() {
            _profiles = [topDoc.data()!];
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openProfileDetail(Map<String, dynamic> data) async {
    HapticFeedback.lightImpact();

    final name = data['name'] as String? ?? 'Your Profile';
    final category = data['networkingCategory'] as String?;
    final cardColors = NetworkingConstants.getCategoryColors(category);

    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored top strip
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: cardColors),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                cardColors[0].withValues(alpha: 0.6),
                                cardColors[1].withValues(alpha: 0.4),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Switch Profile',
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Switch to "$name" in the networking screen?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Poppins', 
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        // Buttons row
                        Row(
                          children: [
                            // Cancel
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(ctx, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Switch
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(ctx, true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE53935),
                                        Color(0xFFB71C1C),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE53935)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Switch',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Poppins', 
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
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
          ),
        ),
      ),
    );

    if (shouldSwitch == true && mounted) {
      await _switchProfileInNetworking(data);
    }
  }

  Future<void> _switchProfileInNetworking(
    Map<String, dynamic> profileData,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Copy selected profile to top-level active doc with discovery enabled
      final activeData = Map<String, dynamic>.from(profileData);
      activeData['discoveryModeEnabled'] = true;
      // Remove subcollection createdAt to avoid conflict
      activeData.remove('createdAt');

      await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .set(activeData);

      if (!mounted) return;

      // Refresh cards on same page
      setState(() => _isLoading = true);
      _loadProfiles();
    } catch (e) {
      debugPrint('Error switching profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to switch profile. Try again.', style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteProfile(Map<String, dynamic> data) async {
    HapticFeedback.lightImpact();
    final name = data['name'] as String? ?? 'Profile';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Profile',
          style: TextStyle(fontFamily: 'Poppins', 
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', 
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'Poppins', 
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // Find and delete the matching doc from subcollection
      final snapshot = await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .collection('profiles')
          .get();

      for (final doc in snapshot.docs) {
        final docData = doc.data();
        if (docData['name'] == data['name'] &&
            docData['networkingCategory'] == data['networkingCategory']) {
          await doc.reference.delete();
          break;
        }
      }
      if (!mounted) return;

      // Check remaining profiles in subcollection
      final remaining = await FirebaseFirestore.instance
          .collection('networking_profiles')
          .doc(uid)
          .collection('profiles')
          .get();

      if (remaining.docs.isEmpty) {
        // Last profile deleted — also delete top-level networking_profiles doc
        await FirebaseFirestore.instance
            .collection('networking_profiles')
            .doc(uid)
            .delete();
        debugPrint('Deleted last networking profile + top-level doc');
      } else {
        // Switch active profile to the first remaining one
        final nextProfile = Map<String, dynamic>.from(remaining.docs.first.data());
        nextProfile.remove('createdAt');
        nextProfile['discoveryModeEnabled'] = true;
        await FirebaseFirestore.instance
            .collection('networking_profiles')
            .doc(uid)
            .set(nextProfile);
        debugPrint('Switched active profile to: ${nextProfile['name']}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining.docs.isEmpty
                  ? 'Networking profile deleted'
                  : 'Profile deleted. Switched to ${remaining.docs.first.data()['name'] ?? 'next profile'}.',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        if (remaining.docs.isEmpty) {
          // No profiles left — go back
          Navigator.pop(context);
        } else {
          setState(() => _isLoading = true);
          _loadProfiles();
        }
      }
    } catch (e) {
      debugPrint('Error deleting profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete profile. Try again.', style: TextStyle(fontFamily: 'Poppins')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: NetworkingWidgets.networkingAppBar(
        title: 'Networking Profile',
        onBack: () => Navigator.pop(context),
      ),
      floatingActionButton: null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(64, 64, 64, 1),
              Color.fromRGBO(40, 40, 40, 1),
              Color.fromRGBO(0, 0, 0, 1),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              )
            : _profiles.isEmpty
                ? _buildEmptyState()
                : _buildProfileList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return NetworkingWidgets.emptyState(
      icon: Icons.person_outline_rounded,
      title: 'No Networking Profile',
      message: 'Create your networking profile to start connecting with people.',
    );
  }

  Widget _buildProfileList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Show all profile cards
        for (final profile in _profiles)
          _buildProfileCard(profile),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Unknown';
    final photoUrl = data['photoUrl'] as String?;
    final category = data['networkingCategory'] as String?;
    final subcategory = data['networkingSubcategory'] as String?;
    final occupation = data['occupation'] as String?;

    final age = data['age'] as num?;
    final gender = data['gender'] as String?;
    final discoveryEnabled = data['discoveryModeEnabled'] == true;
    final interests = (data['interests'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final createdFrom = data['createdFrom'] as String?;
    final createdAt = data['createdAt'];
    String? createdDateStr;
    if (createdAt != null) {
      DateTime? dt;
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      } else if (createdAt is DateTime) {
        dt = createdAt;
      }
      if (dt != null) {
        createdDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      }
    }
    final distanceKm = _getDistanceKm(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: photo + name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile photo
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            color: Colors.grey.shade800,
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white54,
                                      size: 26,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white54,
                                    size: 26,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: discoveryEnabled
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                              boxShadow: discoveryEnabled
                                  ? [
                                      BoxShadow(
                                        color: Colors.greenAccent
                                            .withValues(alpha: 0.7),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Name + occupation
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((occupation != null && occupation.isNotEmpty) ||
                              createdDateStr != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (occupation != null && occupation.isNotEmpty) ...[
                                  Flexible(
                                    child: Text(
                                      occupation,
                                      style: TextStyle(fontFamily: 'Poppins', 
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (createdDateStr != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                                if (createdDateStr != null) ...[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      createdDateStr,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Info chips: category, age, gender, distance
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (category != null && category.isNotEmpty)
                      NetworkingWidgets.infoChip(category, Icons.category_outlined),
                    if (age != null)
                      NetworkingWidgets.infoChip('${age.toInt()} yrs', Icons.cake_outlined),
                    if (gender != null && gender.isNotEmpty)
                      NetworkingWidgets.infoChip(gender, Icons.person_outlined),
                    if (distanceKm != null)
                      NetworkingWidgets.infoChip(
                        distanceKm < 1
                            ? '${(distanceKm * 1000).toInt()} m'
                            : '${distanceKm.toStringAsFixed(1)} km',
                        Icons.near_me_outlined,
                      ),
                  ],
                ),


                // Subcategory + interests
                if ((subcategory != null && subcategory.isNotEmpty) ||
                    interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 8),
                  if (subcategory != null && subcategory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subcategory,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (interests.isNotEmpty)
                    NetworkingWidgets.tagChipWrap(
                      interests.take(4).toList(),
                      spacing: 5,
                      runSpacing: 3,
                    ),
                ],

                const SizedBox(height: 10),

                // Switch + Delete buttons
                Row(
                  children: [
                    // Switch profile button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openProfileDetail(data),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Switch Profile',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Delete profile button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _deleteProfile(data),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Delete Profile',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
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
              ],
            ),
          ),
          // createdFrom badge at top-right
          if (createdFrom != null && createdFrom.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCreatedFromIcon(createdFrom),
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      createdFrom,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCreatedFromIcon(String source) {
    switch (source) {
      case 'Discover All':
        return Icons.explore_outlined;
      case 'Smart':
        return Icons.auto_awesome_outlined;
      case 'My Profiles':
        return Icons.account_box_outlined;
      case 'My Profile':
        return Icons.person_outline_rounded;
      default:
        return Icons.add_circle_outline_rounded;
    }
  }

  double? _getDistanceKm(Map<String, dynamic> data) {
    if (_myLat == null || _myLng == null) return null;
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return NetworkingHelpers.calcDistance(_myLat!, _myLng!, lat, lng);
  }

}
