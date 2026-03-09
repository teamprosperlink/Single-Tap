import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile_detail_screen.dart';
import 'live_connect_tab_screen.dart';
import '../../models/extended_user_profile.dart';
import '../../services/connection_service.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../widgets/networking/networking_helpers.dart';
import '../../widgets/networking/networking_widgets.dart';

class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    super.dispose();
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

    // Fetch full user profile — try networking_profiles first, then users
    ExtendedUserProfile userProfile;
    try {
      final netDoc = await _firestore
          .collection('networking_profiles')
          .doc(userId)
          .get();
      if (netDoc.exists && netDoc.data() != null) {
        userProfile = ExtendedUserProfile.fromMap(netDoc.data()!, userId);
      } else {
        // Fall back to users collection
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
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Connection request accepted!', style: TextStyle(fontFamily: 'Poppins')),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed', style: const TextStyle(fontFamily: 'Poppins')),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
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
    final gradientColors = NetworkingHelpers.getAvatarGradient(userName);
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
            fontFamily: 'Poppins',
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
              // Image fills entire card
              Positioned.fill(
                child: imageWidget,
              ),

              // Top-left: Request type badge (Sent/Received)
              if (requestType != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: NetworkingWidgets.glassBadge(requestType),
                ),

              // Top-right: Time ago badge
              if (timeAgo != null && timeAgo.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: NetworkingWidgets.glassBadge(timeAgo),
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
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
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
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 15,
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
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
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
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    distance < 1
                                        ? '${(distance * 1000).toInt()} m'
                                        : '${distance.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 11,
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
                                          if (!context.mounted) return;
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
                                              SnackBar(
                                                content: const Text(
                                                  'Connection accepted!',
                                                  style: TextStyle(fontFamily: 'Poppins'),
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                margin: const EdgeInsets.all(16),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  result['message'] ?? 'Failed',
                                                  style: const TextStyle(fontFamily: 'Poppins'),
                                                ),
                                                backgroundColor: Colors.red,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                margin: const EdgeInsets.all(16),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isSent ? 'Confirm' : 'Confirm',
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
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
                                        try {
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
                                        } catch (e) {
                                          debugPrint('Error: $e');
                                        }
                                      },
                                      child: Container(
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
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
      appBar: NetworkingWidgets.networkingAppBar(
        title: 'Pending Requests',
        onBack: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: NetworkingWidgets.bodyGradient(),
        child: SafeArea(
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
                        if (receivedSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        if (receivedSnapshot.hasError) {
                          final error = receivedSnapshot.error.toString();
                          return Center(
                            child: Text(
                              'Error: $error',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        final rawRequests = receivedSnapshot.data ?? [];
                        // Deduplicate by otherUserId to avoid showing same person twice
                        final seen = <String>{};
                        final requests = rawRequests.where((req) {
                          final senderId = req['senderId'] as String?;
                          if (senderId == null) return false;
                          return seen.add(senderId);
                        }).toList();
                        requests.sort((a, b) {
                          final aTime = a['createdAt'] as Timestamp?;
                          final bTime = b['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime);
                        });

                        if (requests.isEmpty) {
                          return NetworkingWidgets.emptyState(
                            icon: Icons.person_add_disabled_rounded,
                            title: 'No pending requests',
                            message: 'When someone sends you a connect request,\nit will appear here',
                          );
                        }

                        Widget buildCardAt(int index) {
                          final request = requests[index];
                          final isSent = request['requestType'] == 'sent';
                          final requestId = (request['id'] ?? '').toString();
                          final createdAt = request['createdAt'] as Timestamp?;
                          final timeAgo = createdAt != null
                              ? NetworkingHelpers.formatTimeAgo(createdAt.toDate())
                              : '';

                          final otherUserId = isSent
                              ? (request['receiverId'] ?? '').toString()
                              : (request['senderId'] ?? '').toString();
                          if (requestId.isEmpty || otherUserId.isEmpty) {
                            return const SizedBox.shrink();
                          }

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

                          const double cardHeight = 145.0;

                          // Calculate stored distance for fallback
                          double? storedDist;
                          if (myLat != null &&
                              myLng != null &&
                              storedLat != null &&
                              storedLng != null) {
                            storedDist = NetworkingHelpers.calcDistance(
                              myLat,
                              myLng,
                              storedLat,
                              storedLng,
                            );
                          }
                          final storedAgeInt = storedAge is int
                              ? storedAge
                              : int.tryParse('${storedAge ?? ''}');

                          // Fetch fresh data — try networking_profiles first, fall back to users
                          return FutureBuilder<Map<String, dynamic>>(
                            future: _firestore
                                .collection('networking_profiles')
                                .doc(otherUserId)
                                .get()
                                .then((netDoc) async {
                              if (netDoc.exists && netDoc.data() != null) {
                                return netDoc.data()!;
                              }
                              final userDoc = await _firestore
                                  .collection('users')
                                  .doc(otherUserId)
                                  .get();
                              return userDoc.data() ?? {};
                            }),
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
                                  isCenter: true,
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
                              final userData = userSnap.data ?? {};
                              // Resolve name: name → displayName → phone → storedName → Unknown
                              final name =
                                  NetworkingHelpers.resolveUserName(userData) ??
                                  storedName ??
                                  'Unknown';
                              final photo =
                                  userData['photoUrl'] as String? ??
                                  storedPhoto;
                              final rawAge = userData['age'] ?? storedAge;
                              final fetchedAge =
                                  rawAge ??
                                  NetworkingHelpers.calcAgeFromDob(userData['dateOfBirth']);
                              final occupation =
                                  NetworkingHelpers.resolveOccupation(userData) ??
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
                                fetchedDist = NetworkingHelpers.calcDistance(
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
                                isCenter: true,
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

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(15, 12, 15, 90),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: requests.length,
                          itemBuilder: (context, index) => FloatingCard(
                            animationIndex: index,
                            child: buildCardAt(index),
                          ),
                        );
                  },
                );
              },
            ),
          ),
        ),
    );
  }
}
