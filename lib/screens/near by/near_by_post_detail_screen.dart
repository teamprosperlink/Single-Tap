import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';
import '../../res/utils/snackbar_helper.dart';
import '../../services/notification_service.dart';
import '../call/voice_call_screen.dart';
import '../chat/enhanced_chat_screen.dart';

class NearByPostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;
  final String distanceText;
  final bool isDeleted;
  final bool showCallButton;
  final String tabCategory;

  const NearByPostDetailScreen({
    super.key,
    required this.postId,
    required this.post,
    this.distanceText = '',
    this.isDeleted = false,
    this.showCallButton = true,
    this.tabCategory = 'Products',
  });

  @override
  State<NearByPostDetailScreen> createState() => _NearByPostDetailScreenState();
}

class _NearByPostDetailScreenState extends State<NearByPostDetailScreen> {
  static const _accent = Color(0xFF016CFF);
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isSaved = false;
  bool _isActionLoading = false;
  String _computedDistance = '';
  String _ownerName = '';
  String _ownerPhoto = '';

  static double? _cachedUserLat;
  static double? _cachedUserLng;
  /// Static cache: maps both UUID v5 and Firebase UID → user profile data
  static final Map<String, Map<String, String>> _userProfileCache = {};

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
    _fetchOwnerProfile();
    if (widget.distanceText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _computeDistance();
      });
    }
  }

  /// Fetch the listing owner's name & photo from Firestore.
  /// The API returns user_id as UUID v5 — we reverse-lookup by scanning the
  /// users collection, computing UUID v5 for each Firebase UID, and caching.
  Future<void> _fetchOwnerProfile() async {
    try {
      // If post already has valid userName, use it
      final existingName = (widget.post['userName'] as String?)?.trim() ?? '';
      if (existingName.isNotEmpty && existingName != 'User') {
        if (mounted) {
          setState(() {
            _ownerName = existingName;
            _ownerPhoto = (widget.post['userPhoto'] as String?)?.trim() ?? '';
          });
        }
        return;
      }

      final listingId = (widget.post['listing_id'] as String?)?.trim() ?? widget.postId;
      final apiUserId = (widget.post['user_id'] as String?)?.trim() ?? '';
      debugPrint('OWNER_DEBUG: listingId=$listingId, apiUserId=$apiUserId');

      // Check cache first
      final cacheKey = listingId.isNotEmpty ? listingId : apiUserId;
      if (cacheKey.isNotEmpty && _userProfileCache.containsKey(cacheKey)) {
        final cached = _userProfileCache[cacheKey]!;
        if (mounted) {
          setState(() {
            _ownerName = cached['name'] ?? '';
            _ownerPhoto = cached['photoUrl'] ?? '';
          });
          widget.post['userId'] = cached['firebaseUid'] ?? '';
          widget.post['userName'] = _ownerName;
          widget.post['userPhoto'] = _ownerPhoto;
        }
        return;
      }

      String? firebaseUid;
      String userName = '';
      String userPhoto = '';

      // Strategy 1: Firestore post doc by listing_id as doc ID
      // (api_create_post_screen saves with listingId as doc ID)
      if (listingId.isNotEmpty) {
        final postDoc = await _firestore.collection('posts').doc(listingId).get();
        debugPrint('OWNER_DEBUG: doc($listingId) exists=${postDoc.exists}');
        if (postDoc.exists) {
          final data = postDoc.data() ?? {};
          firebaseUid = data['userId']?.toString();
          userName = data['userName']?.toString() ?? '';
          userPhoto = data['userPhoto']?.toString() ?? '';
        }
      }

      // Strategy 2: Query posts by listingId field
      if (firebaseUid == null && listingId.isNotEmpty) {
        final query = await _firestore
            .collection('posts')
            .where('listingId', isEqualTo: listingId)
            .limit(1)
            .get();
        debugPrint('OWNER_DEBUG: query listingId=$listingId found=${query.docs.length}');
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          firebaseUid = data['userId']?.toString();
          userName = data['userName']?.toString() ?? '';
          userPhoto = data['userPhoto']?.toString() ?? '';
        }
      }

      // Strategy 3: Query posts by originalPrompt matching card title
      if (firebaseUid == null) {
        final titleOriginal = (widget.post['title'] ?? widget.post['originalPrompt'] ?? '').toString().trim();
        if (titleOriginal.isNotEmpty) {
          final query = await _firestore
              .collection('posts')
              .where('originalPrompt', isEqualTo: titleOriginal)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();
          debugPrint('OWNER_DEBUG: query originalPrompt="$titleOriginal" found=${query.docs.length}');
          if (query.docs.isNotEmpty) {
            final data = query.docs.first.data();
            firebaseUid = data['userId']?.toString();
            userName = data['userName']?.toString() ?? '';
            userPhoto = data['userPhoto']?.toString() ?? '';
          }
        }
      }

      // Strategy 4: Lookup api_user_mappings collection
      // (populated when users open nearby feed — maps backend user_id → Firebase UID)
      if (firebaseUid == null && apiUserId.isNotEmpty) {
        final mappingDoc = await _firestore.collection('api_user_mappings').doc(apiUserId).get();
        debugPrint('OWNER_DEBUG: api_user_mappings($apiUserId) exists=${mappingDoc.exists}');
        if (mappingDoc.exists) {
          firebaseUid = mappingDoc.data()?['firebaseUid']?.toString();
        }
      }

      // Strategy 5: Query users collection by user_uuid field
      // (main.dart saves user_uuid for every logged-in user)
      if (firebaseUid == null && apiUserId.isNotEmpty) {
        final userQuery = await _firestore
            .collection('users')
            .where('user_uuid', isEqualTo: apiUserId)
            .limit(1)
            .get();
        debugPrint('OWNER_DEBUG: users query user_uuid=$apiUserId found=${userQuery.docs.length}');
        if (userQuery.docs.isNotEmpty) {
          final doc = userQuery.docs.first;
          firebaseUid = doc.id;
          final data = doc.data();
          userName = data['name']?.toString() ?? '';
          userPhoto = (data['photoUrl'] ?? data['photoURL'] ?? data['profileImageUrl'])?.toString() ?? '';
          // Save to api_user_mappings for faster future lookups
          _firestore.collection('api_user_mappings').doc(apiUserId).set({
            'firebaseUid': firebaseUid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((_) {});
        }
      }

      // Strategy 6: Try user_id directly as Firebase UID
      // (some API responses may return raw Firebase UID instead of UUID v5)
      if (firebaseUid == null && apiUserId.isNotEmpty) {
        final directDoc = await _firestore.collection('users').doc(apiUserId).get();
        debugPrint('OWNER_DEBUG: direct users/$apiUserId exists=${directDoc.exists}');
        if (directDoc.exists) {
          firebaseUid = apiUserId;
          final data = directDoc.data() ?? {};
          userName = data['name']?.toString() ?? '';
          userPhoto = (data['photoUrl'] ?? data['photoURL'] ?? data['profileImageUrl'])?.toString() ?? '';
        }
      }

      // If we found firebaseUid but no name, fetch from users collection
      if (firebaseUid != null && firebaseUid.isNotEmpty && userName.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(firebaseUid).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          userName = data['name']?.toString() ?? '';
          userPhoto = (data['photoUrl'] ?? data['photoURL'] ?? data['profileImageUrl'])?.toString() ?? '';
        }
      }

      debugPrint('OWNER_DEBUG: RESULT uid=$firebaseUid, name=$userName');

      if (firebaseUid != null && firebaseUid.isNotEmpty && mounted) {
        setState(() {
          _ownerName = userName;
          _ownerPhoto = userPhoto;
        });
        widget.post['userId'] = firebaseUid;
        widget.post['userName'] = userName;
        widget.post['userPhoto'] = userPhoto;

        // Cache for future lookups
        final profile = {'name': userName, 'photoUrl': userPhoto, 'firebaseUid': firebaseUid};
        if (listingId.isNotEmpty) _userProfileCache[listingId] = profile;
        if (apiUserId.isNotEmpty) _userProfileCache[apiUserId] = profile;
      }
    } catch (e) {
      debugPrint('Error fetching owner profile: $e');
    }
  }

  Future<void> _computeDistance() async {
    try {
      final postLat = (widget.post['latitude'] as num?)?.toDouble();
      final postLng = (widget.post['longitude'] as num?)?.toDouble();
      if (postLat == null || postLng == null) return;

      double? myLat = _cachedUserLat;
      double? myLng = _cachedUserLng;

      if (myLat == null || myLng == null) {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (userDoc.exists) {
            final city = (userDoc.data()?['city'] as String? ?? '').toLowerCase();
            final rawLat = (userDoc.data()?['latitude'] as num?)?.toDouble();
            final rawLng = (userDoc.data()?['longitude'] as num?)?.toDouble();
            final isMV = city.contains('mountain view') ||
                (rawLat != null && rawLng != null &&
                 (rawLat - 37.422).abs() < 0.05 && (rawLng + 122.084).abs() < 0.05);
            final isNI = rawLat != null && rawLng != null && rawLat.abs() < 0.01 && rawLng.abs() < 0.01;
            if (!isMV && !isNI) {
              myLat = rawLat;
              myLng = rawLng;
            }
          }
        }

        if (myLat == null || myLng == null) {
          final perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
            final pos = await Geolocator.getLastKnownPosition();
            if (pos != null) {
              myLat = pos.latitude;
              myLng = pos.longitude;
            }
          }
        }

        if (myLat != null && myLng != null) {
          _cachedUserLat = myLat;
          _cachedUserLng = myLng;
        }
      }

      if (myLat == null || myLng == null) return;

      const r = 6371.0;
      final dLat = (postLat - myLat) * (pi / 180);
      final dLng = (postLng - myLng) * (pi / 180);
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(myLat * (pi / 180)) *
              cos(postLat * (pi / 180)) *
              sin(dLng / 2) *
              sin(dLng / 2);
      final dist = r * 2 * atan2(sqrt(a), sqrt(1 - a));

      if (dist > 10000) return;

      if (mounted) {
        setState(() {
          _computedDistance = dist < 1
              ? '${(dist * 1000).toInt()} m'
              : '${dist.toStringAsFixed(1)} km';
        });
      }
    } catch (e) {
      debugPrint('Error computing distance: $e');
    }
  }

  Future<void> _checkIfSaved() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(widget.postId)
          .get();
      if (mounted) setState(() => _isSaved = doc.exists);
    } catch (e) {
      debugPrint('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSavePost() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    try {
      final savedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(widget.postId);
      if (_isSaved) {
        await savedRef.delete();
        if (mounted) {
          setState(() => _isSaved = false);
          SnackBarHelper.showSuccess(context, 'Listing unsaved');
        }
      } else {
        await savedRef.set({
          'postId': widget.postId,
          'postData': widget.post,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _isSaved = true);
          SnackBarHelper.showSuccess(context, 'Listing saved');
        }
      }
    } catch (e) {
      debugPrint('Error toggling save: $e');
      if (mounted) SnackBarHelper.showError(context, 'Failed to save listing');
    }
  }

  Map<String, dynamic> get post => widget.post;

  String get _title {
    // Prefer model name (e.g., "iphone 14 pro") like the Home screen card
    final model = (post['model'] ?? '').toString().trim();
    if (model.isNotEmpty) return model;
    final name = (post['title'] ?? post['name'] ?? post['originalPrompt'] ?? 'No Title').toString().trim();
    // Strip brand (raw) prefix and company suffixes
    final rawBrand = (post['brand'] ?? '').toString().trim();
    String cleaned = name;
    if (rawBrand.isNotEmpty && cleaned.toLowerCase().startsWith(rawBrand.toLowerCase())) {
      cleaned = cleaned.substring(rawBrand.length).trim();
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^(inc\.?|ltd\.?|corp\.?|co\.?|llc\.?|pvt\.?)\s*', caseSensitive: false), '').trim();
    return cleaned.isNotEmpty ? cleaned : name;
  }

  String get _brand {
    final raw = (post['brand'] ?? '').toString().trim();
    return raw.replaceAll(RegExp(r'\s*(inc\.?|ltd\.?|corp\.?|co\.?|llc\.?|pvt\.?)$', caseSensitive: false), '').trim();
  }

  String get _description {
    final reasoning = (post['reasoning'] ?? post['smart_message'] ?? '').toString().trim();
    final desc = (post['description'] ?? '').toString().trim();
    return reasoning.isNotEmpty ? reasoning : desc;
  }

  String get _category {
    final feedCat = (post['feedCategory'] ?? '').toString().trim();
    if (feedCat.isNotEmpty) return feedCat;
    final raw = post['category'];
    if (raw is List && raw.isNotEmpty) return raw.first.toString().trim();
    if (raw is String && raw.isNotEmpty) return raw.trim();
    return '';
  }

  bool get _isDonation => post['isDonation'] == true;


  List<String> get _highlights {
    final raw = post['highlights'];
    return (raw is List)
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : [];
  }

  List<String> get _keywords {
    final raw = post['keywords'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    // Build from available data
    final result = <String>[];
    final domain = post['domain'];
    if (domain is List) {
      for (final d in domain) {
        final s = d.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    final category = post['category'];
    if (category is List) {
      for (final c in category) {
        final s = c.toString().trim();
        if (s.isNotEmpty && !result.contains(s)) result.add(s);
      }
    }
    final condition = (post['condition'] ?? '').toString().trim();
    if (condition.isNotEmpty) result.add(condition);
    final itemType = (post['item_type'] ?? post['itemType'] ?? '').toString().trim();
    if (itemType.isNotEmpty && !result.contains(itemType)) result.add(itemType);
    return result;
  }

  List<String> get _imageUrls {
    final urls = <String>[];
    final raw = post['imageUrl'] ?? post['image'];
    if (raw != null && raw.toString().isNotEmpty) urls.add(raw.toString());
    final rawImages = post['images'];
    for (final img in (rawImages is List ? rawImages : <dynamic>[])) {
      final url = img?.toString() ?? '';
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  Widget _buildAvatarAndName() {
    final userPhoto = _ownerPhoto.isNotEmpty
        ? _ownerPhoto
        : (post['userPhoto'] as String?)?.trim() ?? '';
    final name = _ownerName.isNotEmpty
        ? _ownerName
        : post['userName']?.toString().trim() ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            backgroundImage: userPhoto.isNotEmpty
                ? CachedNetworkImageProvider(userPhoto)
                : null,
            child: userPhoto.isNotEmpty
                ? null
                : Text(
                    (name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            name.isNotEmpty ? name : 'User',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _imageUrls;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _isSaved);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context, _isSaved),
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Expanded(
                        child: Center(child: _buildAvatarAndName()),
                      ),
                      if (!widget.isDeleted) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: _toggleSavePost,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Icon(
                                _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: _isSaved ? Colors.white : Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Grid (or placeholder when no images)
                        Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: images.isNotEmpty
                              ? _buildImageGrid(images)
                              : _buildNoImagePlaceholder(),
                        ),

                        // Content Area
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                _title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              // Brand Name
                              if (_brand.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _brand,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Price
                              _buildPriceWidget(),

                              const SizedBox(height: 12),

                              // Category, Type chips
                              _buildInfoChipsRow(),

                              const SizedBox(height: 22),

                              // Description
                              if (_description.isNotEmpty) ...[
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildGlassCard(
                                  child: Text(
                                    _description,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Product Details
                              if (_hasProductDetails) ...[
                                const Text(
                                  'Product Details',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildProductDetailsCard(),
                                const SizedBox(height: 16),
                              ],

                              // Highlights
                              if (_highlights.isNotEmpty) ...[
                                const Text(
                                  'Highlights',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildGlassCard(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _highlights.map((h) => _featureChip(h)).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Keywords
                              if (_keywords.isNotEmpty) ...[
                                const Text(
                                  'Keywords',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildGlassCard(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _keywords.map((k) => _featureChip(k)).toList(),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 110),
                            ],
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
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ── Product Details ──

  bool get _hasProductDetails {
    final brand = _brand;
    final model = (post['model'] ?? '').toString().trim();
    final itemType = (post['item_type'] ?? post['itemType'] ?? '').toString().trim();
    final condition = (post['condition'] ?? '').toString().trim();
    final subintent = (post['subintent'] ?? post['feedCategory'] ?? '').toString().trim();
    final price = post['price'];
    final location = _extractLocationName();
    final domain = post['domain'];
    final domainStr = (domain is List && domain.isNotEmpty) ? domain.first.toString() : (domain is String ? domain : '');
    return brand.isNotEmpty || model.isNotEmpty || itemType.isNotEmpty ||
        condition.isNotEmpty || subintent.isNotEmpty ||
        price != null || location.isNotEmpty || domainStr.isNotEmpty;
  }

  Widget _buildProductDetailsCard() {
    final rows = <MapEntry<String, String>>[];
    final brand = _brand;
    final model = (post['model'] ?? '').toString().trim();
    final itemType = (post['item_type'] ?? post['itemType'] ?? '').toString().trim();
    final condition = (post['condition'] ?? '').toString().trim();
    final subintent = (post['subintent'] ?? post['feedCategory'] ?? '').toString().trim();
    final rawPrice = post['price'];
    final location = _extractLocationName();
    debugPrint('LOCATION_DEBUG: location="$location", post[location]=${post['location']}, post[target_location]=${post['target_location']}, post[_raw_location]=${post['_raw_location']}, reasoning=${(post['reasoning'] ?? '').toString().substring(0, (post['reasoning'] ?? '').toString().length.clamp(0, 100))}');
    final domain = post['domain'];
    final domainStr = (domain is List && domain.isNotEmpty) ? domain.first.toString() : (domain is String ? domain : '');
    final distText = widget.distanceText.isNotEmpty ? widget.distanceText : _computedDistance;

    if (brand.isNotEmpty) rows.add(MapEntry('Brand', _titleCaseStr(brand)));
    if (model.isNotEmpty) rows.add(MapEntry('Model', model));
    if (itemType.isNotEmpty) rows.add(MapEntry('Type', _titleCaseStr(itemType)));
    if (condition.isNotEmpty) rows.add(MapEntry('Condition', _titleCaseStr(condition)));
    if (subintent.isNotEmpty) rows.add(MapEntry('Listing Type', _titleCaseStr(subintent)));
    if (rawPrice != null) {
      final priceNum = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice.toString());
      if (priceNum != null && priceNum > 0) {
        final formatted = priceNum == priceNum.roundToDouble()
            ? '$_currencySymbol${priceNum.toInt()}'
            : '$_currencySymbol${priceNum.toStringAsFixed(2)}';
        rows.add(MapEntry('Budget', formatted));
      }
    }
    if (domainStr.isNotEmpty) rows.add(MapEntry('Domain', _titleCaseStr(domainStr)));
    if (location.isNotEmpty) rows.add(MapEntry('Location', _titleCaseStr(location)));
    // Distance: prefer widget.distanceText, then computed, then API distance_km
    final distFromApi = post['distance_km'];
    String finalDist = distText;
    if (finalDist.isEmpty && distFromApi != null && distFromApi is num && distFromApi > 0) {
      finalDist = distFromApi < 1
          ? '${(distFromApi * 1000).round()} m away'
          : '${distFromApi.toStringAsFixed(1)} km away';
    }
    if (finalDist.isNotEmpty) rows.add(MapEntry('Distance', finalDist));

    return _buildGlassCard(
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.key,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  color: Colors.white.withValues(alpha: 0.08),
                  height: 1,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Extract a proper location name, filtering out distance strings.
  String _extractLocationName() {
    // 1. Check flat location and target_location strings
    for (final key in ['location', 'target_location']) {
      final name = _extractNameFromLocationValue(post[key]);
      debugPrint('LOC_EXTRACT step1 key=$key val=${post[key]} extracted="$name"');
      if (name.isNotEmpty) return name;
    }
    // 2. Check raw location objects passed from toCard()
    for (final key in ['_raw_location', '_raw_target_location']) {
      final raw = post[key];
      final name = _extractNameFromLocationValue(raw);
      debugPrint('LOC_EXTRACT step2 key=$key type=${raw.runtimeType} val=$raw extracted="$name"');
      if (name.isNotEmpty) return name;
    }
    // 3. Fallback: extract location from reasoning/description text
    final reasoning = (post['reasoning'] ?? post['smart_message'] ?? post['description'] ?? '').toString();
    debugPrint('LOC_EXTRACT step3 reasoning_len=${reasoning.length} first100="${reasoning.substring(0, reasoning.length.clamp(0, 100))}"');
    if (reasoning.isNotEmpty) {
      for (final pattern in [
        RegExp(r'(?:mentioned\s+as|specified\s+as|located\s+in|based\s+in|in|from|near|at)\s+([A-Z][a-zA-Z\s,]+?)(?:\.|,\s*(?:so|and|which|that|the)|$)', caseSensitive: true),
        RegExp(r'location[^:]*?(?:is|was|:)\s*([A-Z][a-zA-Z\s,]+?)(?:\.|,\s*(?:so|and|which|that)|$)', caseSensitive: false),
      ]) {
        final locMatch = pattern.firstMatch(reasoning);
        if (locMatch != null) {
          final loc = locMatch.group(1)?.trim() ?? '';
          if (loc.length >= 3 && loc.length <= 80) return loc;
        }
      }
    }
    return '';
  }

  String _extractNameFromLocationValue(dynamic raw) {
    String name = '';
    if (raw is Map) {
      for (final k in ['canonical_name', 'name', 'city', 'locality', 'area', 'address', 'display_name']) {
        final val = raw[k]?.toString().trim() ?? '';
        if (val.isNotEmpty) {
          name = val;
          break;
        }
      }
      // Fallback: first non-null string value (skip metadata keys)
      if (name.isEmpty) {
        for (final entry in raw.entries) {
          final val = entry.value;
          if (val is String && val.trim().isNotEmpty && entry.key != 'match_mode' && entry.key != 'type') {
            name = val.trim();
            break;
          }
        }
      }
    } else if (raw is String) {
      name = raw.trim();
    }
    // Filter out distance-like strings
    if (name.isNotEmpty &&
        !RegExp(r'^\d+(\.\d+)?\s*(km|m|miles?)\b', caseSensitive: false).hasMatch(name) &&
        !name.toLowerCase().endsWith('away')) {
      return name;
    }
    return '';
  }

  String _titleCaseStr(String text) {
    return text.split(' ').map((w) =>
        w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
  }

  // ── Image Grid & Viewer ──

  void _showImageViewer(List<String> images, int initialIndex) {
    final controller = PageController(initialPage: initialIndex);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white38, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 32,
                left: 0, right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (_, __) {
                      final page = (controller.hasClients
                              ? (controller.page ?? initialIndex.toDouble())
                              : initialIndex.toDouble())
                          .round();
                      return Text(
                        '${page + 1} / ${images.length}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData get _categoryIcon {
    final cat = (post['domain'] is List && (post['domain'] as List).isNotEmpty)
        ? (post['domain'] as List).first.toString().toLowerCase()
        : (post['category'] ?? widget.tabCategory).toString().toLowerCase();
    if (cat.contains('food') || cat.contains('restaurant') || cat.contains('dining')) return Icons.restaurant;
    if (cat.contains('electr') || cat.contains('tech') || cat.contains('gadget') || cat.contains('phone') || cat.contains('laptop') || cat.contains('computer')) return Icons.devices;
    if (cat.contains('house') || cat.contains('property') || cat.contains('real estate') || cat.contains('rent') || cat.contains('apartment')) return Icons.home_rounded;
    if (cat.contains('place') || cat.contains('travel') || cat.contains('tour')) return Icons.place;
    if (cat.contains('cloth') || cat.contains('fashion') || cat.contains('wear')) return Icons.checkroom;
    if (cat.contains('vehicle') || cat.contains('car') || cat.contains('bike') || cat.contains('auto')) return Icons.directions_car;
    if (cat.contains('book') || cat.contains('education') || cat.contains('study')) return Icons.menu_book;
    if (cat.contains('health') || cat.contains('medical') || cat.contains('fitness')) return Icons.health_and_safety;
    if (cat.contains('job') || cat.contains('work') || cat.contains('hiring')) return Icons.work;
    if (cat.contains('service')) return Icons.miscellaneous_services;
    return Icons.category;
  }

  String get _categoryLabel {
    final cat = (post['domain'] is List && (post['domain'] as List).isNotEmpty)
        ? (post['domain'] as List).first.toString()
        : (post['category'] ?? widget.tabCategory).toString();
    if (cat.isNotEmpty) {
      return cat.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
    return '';
  }

  Widget _buildNoImagePlaceholder() {
    const double gridHeight = 280.0;
    const double outerRadius = 16.0;
    return Container(
      height: gridHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_categoryIcon, size: 64, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              _categoryLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white24,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    const double gridHeight = 280.0;
    const double gap = 6.0;
    const double imgRadius = 12.0;
    const double outerRadius = 16.0;

    Widget imgBox(String url, {double r = imgRadius, int tapIndex = 0}) {
      final imgWidget = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.image_not_supported, size: 40, color: Colors.white24),
                  ),
                )
              : Container(color: Colors.grey[900]),
        ),
      );
      if (url.isEmpty) return imgWidget;
      return GestureDetector(
        onTap: () => _showImageViewer(images, tapIndex),
        child: imgWidget,
      );
    }

    Widget grid;

    if (images.length == 1) {
      grid = imgBox(images[0], r: outerRadius, tapIndex: 0);
    } else if (images.length == 2) {
      grid = Padding(
        padding: const EdgeInsets.all(gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: imgBox(images[0], tapIndex: 0)),
            const SizedBox(width: gap),
            Expanded(child: imgBox(images[1], tapIndex: 1)),
          ],
        ),
      );
    } else {
      grid = Padding(
        padding: const EdgeInsets.all(gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: imgBox(images[0], tapIndex: 0),
            ),
            const SizedBox(width: gap),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(child: imgBox(images[1], tapIndex: 1)),
                  const SizedBox(height: gap),
                  Expanded(child: imgBox(images.length > 2 ? images[2] : '', tapIndex: 2)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: gridHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(outerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            grid,
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 60,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, top: 0,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, top: 0,
              width: 90,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.0,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0, top: 0,
              width: 90,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.0,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info Chips ──

  String get _currencySymbol {
    final code = (post['currency'] ?? 'INR').toString();
    switch (code) {
      case 'USD': return '\$';
      case 'EUR': return '\u20AC';
      case 'GBP': return '\u00A3';
      case 'AED': return '\u062F.\u0625';
      case 'SAR': return '\uFDFC';
      default: return '\u20B9';
    }
  }


  Widget _buildPriceWidget() {
    final rawPrice = post['price'];
    if (_isDonation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.pinkAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.25)),
        ),
        child: const Text(
          'Free',
          style: TextStyle(fontFamily: 'Poppins', color: Colors.pinkAccent, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (rawPrice == null) return const SizedBox.shrink();
    final formattedPrice = rawPrice is num
        ? (rawPrice == rawPrice.toInt() ? rawPrice.toInt().toString() : rawPrice.toStringAsFixed(2))
        : rawPrice.toString();
    if (formattedPrice.isEmpty || formattedPrice == '0') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$_currencySymbol$formattedPrice',
        style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInfoChipsRow() {
    final chips = <Map<String, dynamic>>[];

    // Category chip (buy/sell/seek/provide)
    if (_category.isNotEmpty) {
      final cat = _category.toLowerCase();
      final (IconData icon, String label, Color color) = switch (cat) {
        'buy' => (Icons.shopping_cart_outlined, 'Buying', Colors.orangeAccent),
        'sell' => (Icons.sell_rounded, 'Selling', Colors.greenAccent),
        'seek' => (Icons.search_rounded, 'Seeking', Colors.cyanAccent),
        'provide' => (Icons.volunteer_activism_rounded, 'Providing', Colors.purpleAccent),
        'mutual' => (Icons.handshake_rounded, 'Mutual Exchange', Colors.amberAccent),
        _ => (Icons.label_outlined, _category, Colors.grey),
      };
      chips.add({
        'icon': icon,
        'text': label,
        'color': color,
        'bgColor': color.withValues(alpha: 0.12),
        'borderColor': color.withValues(alpha: 0.25),
      });
    }

    // Item type chip (e.g., smartphone, laptop)
    final itemType = (post['item_type'] ?? post['itemType'] ?? '').toString().trim();
    if (itemType.isNotEmpty) {
      chips.add({
        'icon': Icons.devices_rounded,
        'text': _titleCaseStr(itemType),
        'color': Colors.lightBlueAccent,
        'bgColor': Colors.lightBlueAccent.withValues(alpha: 0.12),
        'borderColor': Colors.lightBlueAccent.withValues(alpha: 0.25),
      });
    }

    // Condition chip
    final condition = (post['condition'] ?? '').toString().trim();
    if (condition.isNotEmpty) {
      chips.add({
        'icon': Icons.new_releases_rounded,
        'text': _titleCaseStr(condition),
        'color': Colors.tealAccent,
        'bgColor': Colors.tealAccent.withValues(alpha: 0.12),
        'borderColor': Colors.tealAccent.withValues(alpha: 0.25),
      });
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: chips.map((chip) {
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: chip['bgColor'] as Color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: chip['borderColor'] as Color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip['icon'] as IconData, color: chip['color'] as Color, size: 15),
                const SizedBox(width: 6),
                Text(
                  chip['text'] as String,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: chip['color'] as Color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Shared Widgets ──

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _featureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  Future<void> _openChat() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      final receiverId = post['userId'] as String?;
      if (receiverId == null) return;

      if (currentUserId == receiverId) {
        if (mounted) SnackBarHelper.showError(context, 'This is your own listing');
        return;
      }

      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data() ?? {};

      final postUserName = post['userName']?.toString().trim() ?? '';
      final receiverName = postUserName.isNotEmpty
          ? postUserName
          : receiverData['name']?.toString() ?? 'User';
      final receiverPhoto = receiverData['photoUrl']?.toString() ?? '';

      final otherUser = UserProfile(
        uid: receiverId,
        name: receiverName,
        email: receiverData['email']?.toString() ?? '',
        profileImageUrl: receiverPhoto,
        location: receiverData['location']?.toString(),
        latitude: (receiverData['latitude'] as num?)?.toDouble(),
        longitude: (receiverData['longitude'] as num?)?.toDouble(),
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: receiverData['isOnline'] == true,
        interests: (receiverData['interests'] is List)
            ? (receiverData['interests'] as List).map((e) => e.toString()).toList()
            : [],
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedChatScreen(otherUser: otherUser, source: 'NearBy'),
        ),
      );
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to open chat. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _makeVoiceCall() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      final receiverId = post['userId'] as String?;
      if (receiverId == null) return;

      if (currentUserId == receiverId) {
        if (mounted) SnackBarHelper.showError(context, 'You cannot call yourself');
        return;
      }

      final firestore = FirebaseFirestore.instance;

      final meDoc = await firestore.collection('users').doc(currentUserId).get();
      final meData = meDoc.data() ?? {};
      final myName = meData['name']?.toString() ?? 'User';
      final myPhoto = meData['photoUrl']?.toString() ?? '';

      final receiverDoc = await firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data() ?? {};
      final postUserName = post['userName']?.toString().trim() ?? '';
      final receiverName = postUserName.isNotEmpty
          ? postUserName
          : receiverData['name']?.toString() ?? 'User';
      final receiverPhoto = receiverData['photoUrl']?.toString() ?? '';

      final callDoc = await firestore.collection('calls').add({
        'callerId': currentUserId,
        'receiverId': receiverId,
        'callerName': myName,
        'callerPhoto': myPhoto,
        'receiverName': receiverName,
        'receiverPhoto': receiverPhoto,
        'participants': [currentUserId, receiverId],
        'status': 'calling',
        'type': 'audio',
        'source': 'NearBy',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await NotificationService().sendNotificationToUser(
          userId: receiverId,
          title: 'Incoming Call',
          body: '$myName is calling you',
          type: 'call',
          data: {
            'callId': callDoc.id,
            'callerId': currentUserId,
            'callerName': myName,
            'callerPhoto': myPhoto,
          },
        );
      } catch (e) {
        debugPrint('Notification error: $e');
      }

      if (!mounted) return;

      final otherUser = UserProfile(
        uid: receiverId,
        name: receiverName,
        email: receiverData['email']?.toString() ?? '',
        profileImageUrl: receiverPhoto,
        location: receiverData['location']?.toString(),
        latitude: (receiverData['latitude'] as num?)?.toDouble(),
        longitude: (receiverData['longitude'] as num?)?.toDouble(),
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
        isOnline: receiverData['isOnline'] == true,
        interests: (receiverData['interests'] is List)
            ? (receiverData['interests'] as List).map((e) => e.toString()).toList()
            : [],
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
            callId: callDoc.id,
            otherUser: otherUser,
            isOutgoing: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Call error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start call. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _restorePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'isActive': true,
        'deletedAt': FieldValue.delete(),
      });
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Listing restored');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error restoring post: $e');
      if (mounted) SnackBarHelper.showError(context, 'Failed to restore listing');
    }
  }

  Future<void> _permanentlyDeletePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).delete();
      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Listing deleted permanently');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) SnackBarHelper.showError(context, 'Failed to delete listing');
    }
  }

  // ── Bottom Bar ──

  Widget _buildBottomBar() {
    if (widget.isDeleted) return _buildDeletedBottomBar();

    final isOwnPost = post['userId'] == _auth.currentUser?.uid;
    if (isOwnPost) return const SizedBox.shrink();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 14,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              // Chat button
              Expanded(
                child: GestureDetector(
                  onTap: _openChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Chat',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Call button
              Expanded(
                child: GestureDetector(
                  onTap: _makeVoiceCall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_rounded, color: Color(0xFF4CAF50), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Call',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFF4CAF50),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

  Widget _buildDeletedBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).padding.bottom + 14,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _restorePost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accent.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restore_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Restore',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _permanentlyDeletePost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
}
