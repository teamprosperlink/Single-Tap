import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:single_tap/screens/chat/enhanced_chat_screen.dart';
import 'package:single_tap/screens/call/voice_call_screen.dart';
import 'package:single_tap/models/user_profile.dart';
import 'package:single_tap/services/notification_service.dart';
import 'package:single_tap/res/utils/snackbar_helper.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String category;

  const ProductDetailScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _accent = Color(0xFF016CFF);
  bool _isActionLoading = false;
  bool _isSaved = false;
  String _fetchedUserName = '';
  String _fetchedUserPhoto = '';
  String? _resolvedFirebaseUid; // Real Firebase UID resolved from API's UUID

  @override
  void initState() {
    super.initState();
    _fetchSellerInfo();
    _checkSavedStatus();
    debugPrint('ProductDetail: user_id="${widget.item['user_id']}" '
        'listing_id="${widget.item['listing_id']}" '
        'smart_message="${widget.item['smart_message']}" '
        'reasoning="${widget.item['reasoning']}" '
        'location="${widget.item['location']}" '
        '_location_name="${widget.item['_location_name']}" '
        '_raw_location=${widget.item['_raw_location']}');
  }

  Future<void> _fetchSellerInfo() async {
    final apiUserId = widget.item['user_id']?.toString() ?? '';
    debugPrint('ProductDetail: _fetchSellerInfo user_id="$apiUserId"');
    if (apiUserId.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Try direct document lookup (works if user_id IS a Firebase UID)
      final directDoc = await firestore.collection('users').doc(apiUserId).get();
      if (directDoc.exists) {
        debugPrint('ProductDetail: found user by direct doc lookup');
        _resolvedFirebaseUid = apiUserId;
        _applyUserData(directDoc.data()!);
        return;
      }

      // 2. API returns UUID v5, not Firebase UID. Query by user_uuid field.
      debugPrint('ProductDetail: direct lookup failed, querying by user_uuid...');
      final querySnapshot = await firestore
          .collection('users')
          .where('user_uuid', isEqualTo: apiUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty && mounted) {
        final userDoc = querySnapshot.docs.first;
        debugPrint('ProductDetail: found user by user_uuid query: ${userDoc.id}');
        _resolvedFirebaseUid = userDoc.id;
        _applyUserData(userDoc.data());
      } else {
        debugPrint('ProductDetail: user not found by user_uuid either');
      }
    } catch (e) {
      debugPrint('ProductDetail: Failed to fetch seller info: $e');
    }
  }

  void _applyUserData(Map<String, dynamic> data) {
    if (!mounted) return;
    final name = data['name']?.toString() ?? '';
    final photo = (data['photoUrl']?.toString() ?? '').isNotEmpty
        ? data['photoUrl'].toString()
        : data['profileImageUrl']?.toString() ?? '';
    debugPrint('ProductDetail: resolved name="$name" hasPhoto=${photo.isNotEmpty}');
    setState(() {
      _fetchedUserName = name;
      _fetchedUserPhoto = photo;
    });
  }

  String get _postId => widget.item['listing_id']?.toString() ?? '';

  Future<void> _checkSavedStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _postId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(_postId)
          .get();
      if (mounted) setState(() => _isSaved = doc.exists);
    } catch (e) {
      debugPrint('Error checking saved status: $e');
    }
  }

  Future<void> _toggleSavePost() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _postId.isEmpty) return;
    try {
      final savedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_posts')
          .doc(_postId);
      if (_isSaved) {
        await savedRef.delete();
        if (mounted) {
          setState(() => _isSaved = false);
          SnackBarHelper.showSuccess(context, 'Listing unsaved');
        }
      } else {
        await savedRef.set({
          'savedAt': FieldValue.serverTimestamp(),
          ...widget.item,
        });
        if (mounted) {
          setState(() => _isSaved = true);
          SnackBarHelper.showSuccess(context, 'Listing saved');
        }
      }
    } catch (e) {
      debugPrint('Error toggling save: $e');
    }
  }

  bool get _canContact {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final receiverId = _receiverId;
    return receiverId != null && currentUserId != null && currentUserId != receiverId;
  }

  String get _userName => _fetchedUserName.isNotEmpty
      ? _fetchedUserName
      : (widget.item['userName'] as String?)?.trim() ?? '';
  String get _userPhoto => _fetchedUserPhoto.isNotEmpty
      ? _fetchedUserPhoto
      : (widget.item['userPhoto'] as String?)?.trim() ?? '';


  String get _name {
    // Prefer model name (e.g., "iphone 17") like the Home screen card does
    final model = (widget.item['model'] as String?)?.trim() ?? '';
    if (model.isNotEmpty) return model;
    final name = (widget.item['name'] as String?)?.trim() ?? '';
    // Strip brand prefix if brand is shown separately below
    final brand = (widget.item['brand'] as String?)?.trim() ?? '';
    if (brand.isNotEmpty && name.toLowerCase().startsWith(brand.toLowerCase())) {
      final stripped = name.substring(brand.length).trim();
      if (stripped.isNotEmpty) return stripped;
    }
    return name;
  }
  bool get _hasPrice {
    final p = widget.item['price'] as String? ?? '';
    return p.isNotEmpty;
  }
  String get _price => widget.item['price'] as String? ?? '';
  String get _image => widget.item['image'] as String? ?? '';

  String get _brand => widget.item['brand'] as String? ?? '';
  String get _locationName {
    // 1. Prefer preserved original name from home screen
    final saved = widget.item['_location_name']?.toString() ?? '';
    if (saved.isNotEmpty) return saved;
    // 2. Try 'location' field (might be name string from toCardList)
    final loc = widget.item['location'];
    if (loc is String && loc.isNotEmpty && !loc.endsWith('away')) return loc;
    // 3. Extract name from raw location Map
    final raw = widget.item['_raw_location'];
    if (raw is Map) {
      final name = raw['name']?.toString() ?? '';
      if (name.isNotEmpty) return name;
      final canonical = raw['canonical_name']?.toString() ?? '';
      if (canonical.isNotEmpty) return canonical;
    }
    return '';
  }
  String get _location => _locationName;
  String get _condition => widget.item['condition'] as String? ?? '';
  String get _quality => widget.item['quality'] as String? ?? '';
  String get _variant => widget.item['variant'] as String? ?? '';
  String get _subVariant => widget.item['sub_variant'] as String? ?? '';
  String get _color => widget.item['color'] as String? ?? '';
  String get _storage => widget.item['storage'] as String? ?? '';
  String get _budget => widget.item['budget'] as String? ?? '';
  String get _smartMessage {
    final sm = widget.item['smart_message'];
    if (sm != null && sm.toString().isNotEmpty && sm.toString() != 'null') {
      return sm.toString();
    }
    return '';
  }
  String get _reasoning => widget.item['reasoning'] as String? ?? '';
  String get _recommendation => widget.item['recommendation'] as String? ?? '';
  bool get _isSimilarMatch => (widget.item['match_type'] ?? '').toString() == 'similar';
  String get _intent => widget.item['intent'] as String? ?? '';
  String get _subintent => widget.item['subintent'] as String? ?? '';
  String get _itemType => widget.item['item_type'] as String? ?? '';
  String get _targetSubintent => widget.item['targetsubintent'] as String? ?? '';
  String get _relation => widget.item['relation'] as String? ?? '';
  List<String> get _domain {
    final d = widget.item['domain'];
    if (d is List) return d.map((e) => e.toString()).toList();
    return [];
  }
  List<String> get _dataCategory {
    final c = widget.item['data_category'];
    if (c is List) return c.map((e) => e.toString()).toList();
    return [];
  }
  List<Map<String, dynamic>> get _satisfiedConstraints {
    final raw = widget.item['satisfied_constraints'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
  List<Map<String, dynamic>> get _unsatisfiedConstraints {
    final raw = widget.item['unsatisfied_constraints'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
  List<String> get _allImages {
    final imgs = widget.item['images'];
    if (imgs is List) return imgs.cast<String>();
    return _image.isNotEmpty ? [_image] : [];
  }
  Map<String, dynamic>? get _placeMetadata =>
      widget.item['place_metadata'] as Map<String, dynamic>?;
  String get _locationDetail {
    if (_placeMetadata != null) {
      final pm = _placeMetadata!;
      final parts = <String>[];
      final neighborhood = pm['neighborhood'] as String? ?? '';
      final subLocality = pm['sub_locality'] as String? ?? '';
      final locality = pm['locality'] as String? ?? '';
      final city = pm['city'] as String? ?? '';
      final state = pm['state'] as String? ?? '';
      final country = pm['country'] as String? ?? '';
      if (neighborhood.isNotEmpty) parts.add(neighborhood);
      if (subLocality.isNotEmpty) parts.add(subLocality);
      if (locality.isNotEmpty) parts.add(locality);
      if (city.isNotEmpty) parts.add(city);
      if (state.isNotEmpty) parts.add(state);
      if (country.isNotEmpty) parts.add(country);
      final placeName = parts.join(', ');
      if (placeName.isNotEmpty) return placeName;
    }
    return _location;
  }

  double get _matchScore {
    final s = widget.item['match_score'];
    if (s is num) return s.toDouble();
    if (s is String) {
      // Handle "58%" format from home screen - strip % and normalize to 0-1
      final cleaned = s.replaceAll('%', '').trim();
      final v = double.tryParse(cleaned) ?? 0.0;
      return v > 1 ? v / 100 : v; // normalize: 58 → 0.58
    }
    return 0.0;
  }

  IconData get _categoryIcon {
    final cat = widget.category.toLowerCase();
    if (cat.contains('food') || cat.contains('restaurant') || cat.contains('dining')) return Icons.restaurant;
    if (cat.contains('electr') || cat.contains('tech') || cat.contains('gadget') || cat.contains('phone') || cat.contains('laptop') || cat.contains('monitor') || cat.contains('computer')) return Icons.devices;
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
    final cat = widget.category;
    if (cat.isNotEmpty) {
      return cat.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // AppBar with seller profile
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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_userPhoto.isNotEmpty)
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: CachedNetworkImageProvider(_userPhoto),
                              backgroundColor: Colors.white24,
                            )
                          else
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white, size: 18),
                            ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _userName.isNotEmpty ? _userName : _name,
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
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: _toggleSavePost,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: _isSaved ? Colors.white : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Image Grid (collage style)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildImageGrid(_allImages),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            Text(
                              _name,
                              style: const TextStyle(fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
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
                            // Price Row
                            if (_hasPrice) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _accent.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  _price,
                                  style: const TextStyle(fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Quick Info Chips
                            _buildQuickInfoChips(),

                            const SizedBox(height: 22),

                            // Description — only show if API provides reasoning
                            if (_getDescription().isNotEmpty) ...[
                              const Text(
                                'Description',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildGlassCard(
                                child: Text(
                                  _getDescription(),
                                  style: TextStyle(fontFamily: 'Poppins',
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                            ],

                            // Smart Message
                            if (_smartMessage.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Match Insight',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildGlassCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.lightbulb_outline, color: Colors.amber[400], size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _smartMessage,
                                        style: TextStyle(fontFamily: 'Poppins',
                                          color: Colors.grey[300],
                                          fontSize: 12,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Recommendation
                            if (_recommendation.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Recommendation',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildGlassCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.recommend, color: Colors.green[400], size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _recommendation,
                                        style: TextStyle(fontFamily: 'Poppins',
                                          color: Colors.grey[300],
                                          fontSize: 12,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Match Score Badge
                            if (_matchScore > 0) ...[
                              const SizedBox(height: 16),
                              _buildMatchScoreBadge(),
                            ],

                            // Bonus Attributes
                            if (_hasBonusAttributes()) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Additional Info',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildBonusAttributesCard(),
                            ],

                            // Match Analysis (Constraints)
                            if (_satisfiedConstraints.isNotEmpty || _unsatisfiedConstraints.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Match Analysis',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildConstraintsCard(),
                            ],

                            const SizedBox(height: 20),

                            // Product Details section
                            if (_hasProductDetails()) ...[
                              const Text(
                                'Product Details',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildProductDetailsCard(),
                              const SizedBox(height: 20),
                            ],

                            // Seller Info
                            if (_canContact && _userName.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Posted By: $_userName',
                                style: TextStyle(fontFamily: 'Poppins',
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
      bottomNavigationBar: _canContact ? _buildBottomBar() : null,
    );
  }

  Widget _buildQuickInfoChips() {
    final chips = <Map<String, dynamic>>[];

    if (_itemType.isNotEmpty) {
      chips.add({'icon': Icons.category_outlined, 'text': _itemType});
    }
    if (_brand.isNotEmpty) {
      chips.add({'icon': Icons.business_rounded, 'text': _brand});
    }
    if (_variant.isNotEmpty || _subVariant.isNotEmpty) {
      final variantStr = [_variant, _subVariant].where((v) => v.isNotEmpty).join(' ');
      chips.add({'icon': Icons.style_outlined, 'text': variantStr});
    }
    if (_color.isNotEmpty) {
      chips.add({'icon': Icons.palette_outlined, 'text': _color});
    }
    if (_storage.isNotEmpty) {
      chips.add({'icon': Icons.sd_storage_outlined, 'text': _storage});
    }
    if (_condition.isNotEmpty) {
      chips.add({'icon': Icons.verified_outlined, 'text': _condition});
    }
    if (_quality.isNotEmpty) {
      chips.add({'icon': Icons.star_outline_rounded, 'text': _quality});
    }
    if (_subintent.isNotEmpty) {
      chips.add({'icon': Icons.swap_horiz_rounded, 'text': _subintent});
    }

    if (chips.isEmpty) {
      chips.add({'icon': Icons.info_outline, 'text': _name});
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chip['icon'] as IconData, color: _accent, size: 14),
              const SizedBox(width: 5),
              Text(
                chip['text'] as String,
                style: const TextStyle(fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getDescription() {
    // Use reasoning directly from API — no fallback to smartMessage (shown in Match Insight)
    return _reasoning;
  }

  bool _hasProductDetails() {
    // Only fields NOT already shown in Quick Info Chips or Match Score Badge
    return _intent.isNotEmpty ||
        (_targetSubintent.isNotEmpty && _targetSubintent != _subintent) ||
        (_budget.isNotEmpty && _budget != _price) ||
        _locationDetail.isNotEmpty ||
        _domain.isNotEmpty ||
        _dataCategory.isNotEmpty ||
        widget.category.isNotEmpty;
  }

  Widget _buildProductDetailsCard() {
    // Only fields NOT already shown in Quick Info Chips or Match Score Badge
    final rows = <MapEntry<String, String>>[];
    if (_intent.isNotEmpty) rows.add(MapEntry('Intent', _intent));
    if (_targetSubintent.isNotEmpty && _targetSubintent != _subintent) {
      rows.add(MapEntry('Looking For', _targetSubintent));
    }
    if (_budget.isNotEmpty && _budget != _price) rows.add(MapEntry('Budget', _budget));
    if (_locationDetail.isNotEmpty) rows.add(MapEntry('Location', _locationDetail));
    if (_domain.isNotEmpty) rows.add(MapEntry('Domain', _domain.join(', ')));
    if (_dataCategory.isNotEmpty) rows.add(MapEntry('Category', _dataCategory.join(', ')));
    if (_dataCategory.isEmpty && widget.category.isNotEmpty) rows.add(MapEntry('Category', _categoryLabel));

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
                        row.value.isNotEmpty
                            ? row.value[0].toUpperCase() + row.value.substring(1)
                            : '',
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

  Map<String, dynamic> get _bonusAttributes {
    final raw = widget.item['bonus_attributes'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  bool _hasBonusAttributes() {
    final bonus = _bonusAttributes;
    if (bonus.isEmpty) return false;
    // Only show if there are attributes not already displayed elsewhere
    final displayedKeys = {'brand', 'items[0].brand', 'condition', 'items[0].condition',
      'quality', 'items[0].quality', 'price', 'items[0].price',
      'model', 'items[0].model', 'variant', 'items[0].variant',
      'sub_variant', 'items[0].sub_variant', 'color', 'items[0].color',
      'storage', 'items[0].storage'};
    return bonus.keys.any((k) => !displayedKeys.contains(k) && bonus[k] != null);
  }

  String _cleanBonusKey(String key) {
    // "items[0].model" → "Model", "items[0].budget" → "Budget"
    var cleaned = key.replaceAll(RegExp(r'items\[\d+\]\.'), '');
    cleaned = cleaned.replaceAll('_', ' ');
    if (cleaned.isEmpty) return key;
    return cleaned.split(' ').map((w) =>
      w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}'
    ).join(' ');
  }

  Widget _buildBonusAttributesCard() {
    final bonus = _bonusAttributes;
    final displayedKeys = {'brand', 'items[0].brand', 'condition', 'items[0].condition',
      'quality', 'items[0].quality', 'price', 'items[0].price',
      'model', 'items[0].model', 'variant', 'items[0].variant',
      'sub_variant', 'items[0].sub_variant', 'color', 'items[0].color',
      'storage', 'items[0].storage'};

    final entries = bonus.entries
        .where((e) => !displayedKeys.contains(e.key) && e.value != null)
        .toList();

    return _buildGlassCard(
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final isLast = entry.key == entries.length - 1;
          final e = entry.value;
          final displayValue = e.value.toString();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _cleanBonusKey(e.key),
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
                        displayValue[0].toUpperCase() + displayValue.substring(1),
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

  Widget _buildMatchScoreBadge() {
    final scorePercent = (_matchScore * 100).toStringAsFixed(0);
    final isExact = _matchScore >= 1.0 || !_isSimilarMatch;
    return _buildGlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isExact
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [Colors.orange.shade600, Colors.orange.shade400],
              ),
            ),
            child: Center(
              child: Text(
                '$scorePercent%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExact ? 'Exact Match' : 'Similar Match',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_relation.isNotEmpty)
                  Text(
                    _relation,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintsCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_satisfiedConstraints.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[400], size: 16),
                const SizedBox(width: 6),
                Text(
                  'Matched (${_satisfiedConstraints.length})',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._satisfiedConstraints.map((c) => _buildConstraintRow(c, true)),
          ],
          if (_satisfiedConstraints.isNotEmpty && _unsatisfiedConstraints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            ),
          if (_unsatisfiedConstraints.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[400], size: 16),
                const SizedBox(width: 6),
                Text(
                  'Differs (${_unsatisfiedConstraints.length})',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._unsatisfiedConstraints.map((c) => _buildConstraintRow(c, false)),
          ],
        ],
      ),
    );
  }

  /// Extract a display-friendly string from a constraint value that might be
  /// a Map (e.g. location objects like {name: mumbai, coordinates: {...}}).
  String _constraintValueToString(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      // Location-like map: extract name
      final name = value['name']?.toString() ?? '';
      if (name.isNotEmpty) return name;
      final canonical = value['canonical_name']?.toString() ?? '';
      if (canonical.isNotEmpty) return canonical;
      // Fallback: join non-map values
      return value.values
          .where((v) => v is! Map && v is! List)
          .map((v) => v.toString())
          .join(', ');
    }
    final str = value.toString();
    // Detect stringified Map like "{name: mumbai, coordinates: ...}"
    if (str.startsWith('{') && str.contains('name:')) {
      final match = RegExp(r'name:\s*([^,}]+)').firstMatch(str);
      if (match != null) return match.group(1)!.trim();
    }
    return str;
  }

  Widget _buildConstraintRow(Map<String, dynamic> constraint, bool passed) {
    final field = constraint['field']?.toString() ?? '';
    final required = _constraintValueToString(constraint['required']);
    final actual = _constraintValueToString(constraint['actual']);
    final deviation = constraint['deviation']?.toString() ?? '';

    if (field.isEmpty) return const SizedBox.shrink();

    // Clean field name: "items[0].brand" → "Brand"
    var displayField = field.replaceAll(RegExp(r'items\[\d+\]\.'), '');
    displayField = displayField.replaceAll('_', ' ');
    if (displayField.isNotEmpty) {
      displayField = displayField.split(' ').map((w) =>
        w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}'
      ).join(' ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 22),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              displayField,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              passed
                  ? actual.isNotEmpty ? actual : required
                  : '${required.isNotEmpty ? "Wanted: $required" : ""}${actual.isNotEmpty ? " · Got: $actual" : ""}${deviation.isNotEmpty ? " ($deviation)" : ""}',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: passed ? Colors.green[300] : Colors.orange[300],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

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
              : Container(
                  color: const Color(0xFF1A1A2E),
                  child: Center(
                    child: Icon(_categoryIcon, size: 48, color: Colors.white24),
                  ),
                ),
        ),
      );
      if (url.isEmpty) return imgWidget;
      return GestureDetector(
        onTap: () => _showImageViewer(images, tapIndex),
        child: imgWidget,
      );
    }

    Widget grid;

    if (images.isEmpty) {
      grid = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(outerRadius),
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
    } else if (images.length == 1) {
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
            // Left edge gradient
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
            // Right edge gradient
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
            // Top gradient
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
            // Bottom gradient
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
            // Top-left corner gradient
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
            // Top-right corner gradient
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

  Widget _buildBottomBar() {
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
              // Price removed from bottom bar
              // Chat Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _openChat();
                  },
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
              // Call Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _makeVoiceCall();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Call',
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
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the real Firebase UID of the post owner (resolved from UUID if needed)
  String? get _receiverId {
    // Prefer resolved Firebase UID over the raw API UUID
    if (_resolvedFirebaseUid != null && _resolvedFirebaseUid!.isNotEmpty) {
      return _resolvedFirebaseUid;
    }
    final id = widget.item['user_id'] as String? ?? '';
    return id.isEmpty ? null : id;
  }

  String get _productInfoMessage {
    final parts = <String>[];
    parts.add('Hi! I\'m interested in your listing:');
    parts.add('📌 $_name');
    if (_hasPrice) parts.add('💰 Price: $_price');
    if (_brand.isNotEmpty) parts.add('🏷️ $_brand');
    if (_location.isNotEmpty) parts.add('📍 $_location');
    return parts.join('\n');
  }

  Future<void> _openChat() async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      final receiverId = _receiverId;
      if (receiverId == null) {
        if (mounted) SnackBarHelper.showError(context, 'User not available');
        return;
      }
      if (currentUserId == receiverId) {
        if (mounted) SnackBarHelper.showError(context, 'This is your own listing');
        return;
      }

      // Fetch full profile using resolved Firebase UID
      Map<String, dynamic> receiverData = {};
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
        if (doc.exists) receiverData = doc.data() ?? {};
      } catch (_) {}
      if (!mounted) return;

      final receiverName = (receiverData['name']?.toString() ?? '').isNotEmpty
          ? receiverData['name'].toString()
          : _userName.isNotEmpty ? _userName : 'User';
      final receiverPhoto = (receiverData['photoUrl']?.toString() ?? '').isNotEmpty
          ? receiverData['photoUrl'].toString()
          : (receiverData['profileImageUrl']?.toString() ?? '').isNotEmpty
              ? receiverData['profileImageUrl'].toString()
              : _userPhoto;

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
          builder: (_) => EnhancedChatScreen(otherUser: otherUser, source: 'Product', initialMessage: _productInfoMessage),
        ),
      );
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to open chat');
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
      final receiverId = _receiverId;
      if (receiverId == null) {
        if (mounted) SnackBarHelper.showError(context, 'User not available');
        return;
      }
      if (currentUserId == receiverId) {
        if (mounted) SnackBarHelper.showError(context, 'You cannot call yourself');
        return;
      }

      final firestore = FirebaseFirestore.instance;

      final meDoc = await firestore.collection('users').doc(currentUserId).get();
      final meData = meDoc.data() ?? {};
      final myName = meData['name']?.toString() ?? 'User';
      final myPhoto = meData['photoUrl']?.toString() ?? '';

      Map<String, dynamic> receiverData = {};
      try {
        final receiverDoc = await firestore.collection('users').doc(receiverId).get();
        if (receiverDoc.exists) receiverData = receiverDoc.data() ?? {};
      } catch (e) {
        debugPrint('Failed to fetch receiver profile: $e');
      }
      // Use Firestore data first, then pre-fetched seller info
      final receiverName = (receiverData['name']?.toString() ?? '').isNotEmpty
          ? receiverData['name'].toString()
          : _userName.isNotEmpty
              ? _userName
              : 'User';
      final receiverPhoto = (receiverData['photoUrl']?.toString() ?? '').isNotEmpty
          ? receiverData['photoUrl'].toString()
          : (receiverData['profileImageUrl']?.toString() ?? '').isNotEmpty
              ? receiverData['profileImageUrl'].toString()
              : _userPhoto;

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
        'source': 'Product',
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

      // After call ends, open chat screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedChatScreen(otherUser: otherUser, source: 'Product', initialMessage: _productInfoMessage),
        ),
      );
    } catch (e) {
      debugPrint('Call error: $e');
      if (mounted) {
        SnackBarHelper.showError(context, 'Failed to start call');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

}
