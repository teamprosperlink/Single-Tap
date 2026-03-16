import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../models/user_profile.dart';
import 'public_business_profile_screen.dart';

class NearbyBusinessesScreen extends StatefulWidget {
  final double? userLat;
  final double? userLng;

  const NearbyBusinessesScreen({super.key, this.userLat, this.userLng});

  @override
  State<NearbyBusinessesScreen> createState() =>
      _NearbyBusinessesScreenState();
}

class _NearbyBusinessesScreenState extends State<NearbyBusinessesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserProfile> _businesses = [];
  bool _isLoading = true;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() => _isLoading = true);
    }

    try {
      var query = _firestore
          .collection('users')
          .where('accountType', isEqualTo: 'business')
          .limit(_pageSize);

      if (loadMore && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();

      final profiles = snap.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();

      // Sort by distance if user location available
      if (widget.userLat != null && widget.userLng != null) {
        profiles.sort((a, b) {
          final distA = _distance(a.latitude, a.longitude);
          final distB = _distance(b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
      }

      setState(() {
        if (loadMore) {
          _businesses.addAll(profiles);
        } else {
          _businesses = profiles;
        }
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading businesses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _distance(double? lat, double? lng) {
    if (lat == null || lng == null || widget.userLat == null || widget.userLng == null) {
      return double.infinity;
    }
    // Haversine approximation in km
    const r = 6371.0;
    final dLat = _toRad(lat - widget.userLat!);
    final dLng = _toRad(lng - widget.userLng!);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(widget.userLat!)) *
            cos(_toRad(lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  String _formatDistance(double? lat, double? lng) {
    final d = _distance(lat, lng);
    if (d == double.infinity) return '';
    if (d < 1) return '${(d * 1000).round()}m away';
    return '${d.toStringAsFixed(1)}km away';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Nearby Businesses'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businesses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(height: 16),
                      Text('No businesses nearby',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Check back later',
                          style: TextStyle(
                              color: subtitleColor, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _businesses.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == _businesses.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => _loadBusinesses(loadMore: true),
                          child: const Text('Load more'),
                        ),
                      );
                    }

                    final biz = _businesses[index];
                    final bp = biz.businessProfile;
                    final isOpen = bp?.isCurrentlyOpen ?? false;
                    final dist =
                        _formatDistance(biz.latitude, biz.longitude);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicBusinessProfileScreen(
                              userId: biz.uid,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 26,
                              backgroundImage:
                                  biz.profileImageUrl != null
                                      ? NetworkImage(
                                          biz.profileImageUrl!)
                                      : null,
                              child: biz.profileImageUrl == null
                                  ? Text(
                                      biz.name.isNotEmpty
                                          ? biz.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          bp?.businessName ?? biz.name,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Business badge
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB300)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: Color(0xFFFFB300),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (bp?.softLabel != null) ...[
                                        Text(
                                          bp!.softLabel!,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (dist.isNotEmpty)
                                          Text(' \u2022 ',
                                              style: TextStyle(
                                                  color: subtitleColor,
                                                  fontSize: 13)),
                                      ],
                                      if (dist.isNotEmpty)
                                        Text(dist,
                                            style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Open/Closed chip
                            if (bp?.hours != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFF22C55E)
                                          .withValues(alpha: 0.15)
                                      : Colors.red
                                          .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOpen ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    color: isOpen
                                        ? const Color(0xFF22C55E)
                                        : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
