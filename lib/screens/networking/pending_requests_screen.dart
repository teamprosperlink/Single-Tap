import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supper/screens/networking/onboarding_networking_screen.dart';

import 'user_profile_detail_screen.dart';
import '../../models/extended_user_profile.dart';
import '../../services/connection_service.dart';
import '../../res/utils/photo_url_helper.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  static const int columnCount = 5;
  static const double cardWidth = 145.0;
  static const double spacing = 8.0;
  static const List<double> heightPattern = [180, 240, 200, 260, 210];

  String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  double calcDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Resolve user display name from Firestore data, checking multiple fields
  String? _resolveUserName(Map<String, dynamic> data) {
    final name = data['name'] as String?;
    if (name != null &&
        name.isNotEmpty &&
        name != 'User' &&
        name != 'Unknown') {
      return name;
    }
    final displayName = data['displayName'] as String?;
    if (displayName != null &&
        displayName.isNotEmpty &&
        displayName != 'User' &&
        displayName != 'Unknown') {
      return displayName;
    }
    final phone = data['phone'] as String?;
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return null;
  }

  /// Calculate age from dateOfBirth string (ISO8601) if age field is null
  int? _calcAgeFromDob(dynamic dob) {
    if (dob == null) return null;
    try {
      final DateTime birthDate;
      if (dob is Timestamp) {
        birthDate = dob.toDate();
      } else if (dob is String && dob.isNotEmpty) {
        birthDate = DateTime.parse(dob);
      } else {
        return null;
      }
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  /// Resolve occupation from multiple possible fields
  String? _resolveOccupation(Map<String, dynamic> data) {
    final occupation = data['occupation'] as String?;
    if (occupation != null && occupation.isNotEmpty) return occupation;
    final profession = data['profession'] as String?;
    if (profession != null && profession.isNotEmpty) return profession;
    // Check professional profile
    final profProfile = data['professionalProfile'] as Map<String, dynamic>?;
    if (profProfile != null) {
      final category = profProfile['category'] as String?;
      if (category != null && category.isNotEmpty) return category;
    }
    // Check networking subcategory
    final subcat = data['networkingSubcategory'] as String?;
    if (subcat != null && subcat.isNotEmpty) return subcat;
    return null;
  }

  List<Color> _getAvatarGradient(String name) {
    final hash = name.hashCode % 5;
    switch (hash) {
      case 0:
        return [const Color(0xFFFF6B9D), const Color(0xFFC7365F)];
      case 1:
        return [const Color(0xFF4A90E2), const Color(0xFF2E5BFF)];
      case 2:
        return [const Color(0xFFFF6B35), const Color(0xFFFF4E00)];
      case 3:
        return [const Color(0xFF9B59B6), const Color(0xFF6C3483)];
      default:
        return [const Color(0xFF00D67D), const Color(0xFF00A85E)];
    }
  }

  void _showProfileDetail({
    required String userId,
    required String name,
    required String? photo,
    required dynamic age,
    required String? occupation,
    required double? lat,
    required double? lng,
    required String requestId,
    required ConnectionService connectionService,
    required bool isSent,
  }) async {
    HapticFeedback.lightImpact();

    // Fetch full user profile from Firestore
    ExtendedUserProfile userProfile;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        userProfile = ExtendedUserProfile.fromMap(userDoc.data()!, userId);
      } else {
        // Fallback to minimal data from connection request
        userProfile = ExtendedUserProfile(
          uid: userId,
          name: name,
          photoUrl: photo,
          age: age is int ? age : int.tryParse('$age'),
          occupation: occupation,
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (e) {
      // Fallback to minimal data on error
      userProfile = ExtendedUserProfile(
        uid: userId,
        name: name,
        photoUrl: photo,
        age: age is int ? age : int.tryParse('$age'),
        occupation: occupation,
        latitude: lat,
        longitude: lng,
      );
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileDetailScreen(
          user: userProfile,
          connectionStatus: isSent ? 'sent' : 'received',
          onConnect: isSent
              ? null
              : () async {
                  final result = await connectionService
                      .acceptConnectionRequest(requestId);
                  if (!mounted) return;
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Connection request accepted!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
        ),
      ),
    );
  }

  Widget _buildMosaicCard({
    required String userName,
    required String? imageUrl,
    required double height,
    required VoidCallback onTap,
    bool isCenter = false,
    int? age,
    String? profession,
    double? distance,
    String? requestType,
    String? timeAgo,
    bool isOnline = false,
    String? networkingCategory,
    String? requestId,
    ConnectionService? connectionService,
    bool isSent = false,
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
          errorBuilder: (context, error, stackTrace) => placeholderWidget,
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
              // Image fills entire card — grayscale for non-center cards
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

              // Top-left: Request type badge (Sent/Received)
              if (requestType != null)
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
                          requestType,
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

              // Top-right: Time ago badge
              if (timeAgo != null && timeAgo.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
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
                          timeAgo,
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

              // Glassmorphism info card at bottom (matching Smart tab style)
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
                          // Name + age row with online dot
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
                          // Profession
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
                          // Confirm / Delete buttons
                          if (requestId != null && connectionService != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        HapticFeedback.mediumImpact();
                                        if (isSent) {
                                          await connectionService
                                              .cancelConnectionRequest(
                                                requestId,
                                              );
                                        } else {
                                          final result = await connectionService
                                              .acceptConnectionRequest(
                                                requestId,
                                              );
                                          if (!context.mounted) return;
                                          if (result['success'] == true) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Connection accepted!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  result['message'] ?? 'Failed',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isSent ? 'Cancel' : 'Confirm',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        HapticFeedback.lightImpact();
                                        if (isSent) {
                                          await connectionService
                                              .cancelConnectionRequest(
                                                requestId,
                                              );
                                        } else {
                                          await connectionService
                                              .rejectConnectionRequest(
                                                requestId,
                                              );
                                        }
                                      },
                                      child: Container(
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white70,
                                            ),
                                          ),
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

  @override
  Widget build(BuildContext context) {
    final connectionService = ConnectionService();
    final currentUid = _auth.currentUser?.uid;

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
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        title: const Text(
          'Pending Requests',
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
            border: Border(bottom: BorderSide(color: Colors.white, width: 0.5)),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(64, 64, 64, 1), // #404040
              Color.fromRGBO(0, 0, 0, 1), // #000000
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: FutureBuilder<DocumentSnapshot>(
              future: currentUid != null
                  ? _firestore.collection('users').doc(currentUid).get()
                  : null,
              builder: (context, mySnap) {
                final myData = mySnap.data?.data() as Map<String, dynamic>?;
                final myLat = (myData?['latitude'] as num?)?.toDouble();
                final myLng = (myData?['longitude'] as num?)?.toDouble();

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: connectionService.getPendingRequestsStream(),
                  builder: (context, receivedSnapshot) {
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: connectionService.getSentRequestsStream(),
                      builder: (context, sentSnapshot) {
                        if (receivedSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            sentSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        if (receivedSnapshot.hasError ||
                            sentSnapshot.hasError) {
                          final error =
                              (receivedSnapshot.error ?? sentSnapshot.error)
                                  .toString();
                          return Center(
                            child: Text(
                              'Error: $error',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        final received = receivedSnapshot.data ?? [];
                        final sent = sentSnapshot.data ?? [];
                        final requests = [...received, ...sent];
                        requests.sort((a, b) {
                          final aTime = a['createdAt'] as Timestamp?;
                          final bTime = b['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });

                        if (requests.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_disabled_rounded,
                                  size: 72,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No pending requests',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'When someone sends you a connect request,\nit will appear here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final actualColumns = requests.length < columnCount
                            ? requests.length
                            : columnCount;
                        final List<List<int>> columns = List.generate(
                          actualColumns,
                          (_) => [],
                        );
                        for (int i = 0; i < requests.length; i++) {
                          columns[i % actualColumns].add(i);
                        }

                        // Colorful cards — every 3rd card shows in full color
                        bool isColorCard(int index) => index % 3 == 0;

                        Widget buildCardAt(int index) {
                          final request = requests[index];
                          final isSent = request['requestType'] == 'sent';
                          final requestId = request['id'] as String;
                          final createdAt = request['createdAt'] as Timestamp?;
                          final timeAgo = createdAt != null
                              ? formatTimeAgo(createdAt.toDate())
                              : '';

                          final otherUserId = isSent
                              ? request['receiverId'] as String
                              : request['senderId'] as String;

                          final storedName = isSent
                              ? request['receiverName'] as String?
                              : request['senderName'] as String?;
                          final storedPhoto = isSent
                              ? request['receiverPhoto'] as String?
                              : request['senderPhoto'] as String?;
                          final storedAge = isSent
                              ? request['receiverAge']
                              : request['senderAge'];
                          final storedOccupation = isSent
                              ? request['receiverOccupation'] as String?
                              : request['senderOccupation'] as String?;
                          final storedLat = isSent
                              ? (request['receiverLatitude'] as num?)
                                    ?.toDouble()
                              : (request['senderLatitude'] as num?)?.toDouble();
                          final storedLng = isSent
                              ? (request['receiverLongitude'] as num?)
                                    ?.toDouble()
                              : (request['senderLongitude'] as num?)
                                    ?.toDouble();

                          final int col = index % columnCount;
                          final int row = index ~/ columnCount;
                          final double cardHeight =
                              heightPattern[(col + row) % heightPattern.length];

                          // Calculate stored distance for fallback
                          double? storedDist;
                          if (myLat != null &&
                              myLng != null &&
                              storedLat != null &&
                              storedLng != null) {
                            storedDist = calcDistance(
                              myLat,
                              myLng,
                              storedLat,
                              storedLng,
                            );
                          }
                          final storedAgeInt = storedAge is int
                              ? storedAge
                              : int.tryParse('${storedAge ?? ''}');

                          // Always fetch fresh user data from Firestore
                          return FutureBuilder<DocumentSnapshot>(
                            future: _firestore
                                .collection('users')
                                .doc(otherUserId)
                                .get(),
                            builder: (context, userSnap) {
                              // Show card with stored data while loading
                              if (userSnap.connectionState ==
                                  ConnectionState.waiting) {
                                final fallbackPhoto = storedPhoto != null
                                    ? PhotoUrlHelper.fixGooglePhotoUrl(
                                        storedPhoto,
                                      )
                                    : null;
                                return _buildMosaicCard(
                                  userName: storedName ?? 'Loading...',
                                  imageUrl: fallbackPhoto,
                                  height: cardHeight,
                                  isCenter: isColorCard(index),
                                  onTap: () {},
                                  age: storedAgeInt,
                                  profession: storedOccupation,
                                  distance: storedDist,
                                  requestType: isSent ? 'Sent' : 'Received',
                                  timeAgo: timeAgo,
                                  requestId: requestId,
                                  connectionService: connectionService,
                                  isSent: isSent,
                                );
                              }
                              final userData =
                                  userSnap.data?.data()
                                      as Map<String, dynamic>? ??
                                  {};
                              // Resolve name: name → displayName → phone → storedName → Unknown
                              final name =
                                  _resolveUserName(userData) ??
                                  storedName ??
                                  'Unknown';
                              final photo =
                                  userData['photoUrl'] as String? ??
                                  storedPhoto;
                              final rawAge = userData['age'] ?? storedAge;
                              final fetchedAge =
                                  rawAge ??
                                  _calcAgeFromDob(userData['dateOfBirth']);
                              final occupation =
                                  _resolveOccupation(userData) ??
                                  storedOccupation;
                              final userLat =
                                  (userData['latitude'] as num?)?.toDouble() ??
                                  storedLat;
                              final userLng =
                                  (userData['longitude'] as num?)?.toDouble() ??
                                  storedLng;
                              final isOnline =
                                  userData['isOnline'] as bool? ?? false;
                              final networkingCat =
                                  userData['networkingCategory'] as String?;

                              double? fetchedDist;
                              if (myLat != null &&
                                  myLng != null &&
                                  userLat != null &&
                                  userLng != null) {
                                fetchedDist = calcDistance(
                                  myLat,
                                  myLng,
                                  userLat,
                                  userLng,
                                );
                              }

                              final fixedPhoto = photo != null
                                  ? PhotoUrlHelper.fixGooglePhotoUrl(photo)
                                  : null;

                              return _buildMosaicCard(
                                userName: name,
                                imageUrl: fixedPhoto,
                                height: cardHeight,
                                isCenter: isColorCard(index),
                                onTap: () => _showProfileDetail(
                                  userId: otherUserId,
                                  name: name,
                                  photo: fixedPhoto,
                                  age: fetchedAge,
                                  occupation: occupation,
                                  lat: userLat,
                                  lng: userLng,
                                  requestId: requestId,
                                  connectionService: connectionService,
                                  isSent: isSent,
                                ),
                                age: fetchedAge is int
                                    ? fetchedAge
                                    : int.tryParse('${fetchedAge ?? ''}'),
                                profession: occupation,
                                distance: fetchedDist,
                                requestType: isSent ? 'Sent' : 'Received',
                                timeAgo: timeAgo,
                                isOnline: isOnline,
                                networkingCategory: networkingCat,
                                requestId: requestId,
                                connectionService: connectionService,
                                isSent: isSent,
                              );
                            },
                          );
                        }

                        // Scroll to center only when content is wider than screen
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_horizontalScrollController.hasClients &&
                              _horizontalScrollController.position.pixels ==
                                  0) {
                            final totalWidth =
                                (cardWidth + spacing) * actualColumns -
                                spacing +
                                24;
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final centerOffset = (totalWidth - screenWidth) / 2;
                            if (centerOffset > 0) {
                              _horizontalScrollController.jumpTo(centerOffset);
                            }
                          }
                        });

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 12, 16, 90),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(actualColumns, (
                                  colIndex,
                                ) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: colIndex < actualColumns - 1
                                          ? spacing
                                          : 0,
                                    ),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        children: columns[colIndex].map((
                                          cardIndex,
                                        ) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: spacing,
                                            ),
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
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
