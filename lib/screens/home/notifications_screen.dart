import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'main_navigation_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _nameCache = {};

  Future<String> _getSenderName(String? senderId) async {
    if (senderId == null || senderId.isEmpty) return 'Someone';
    if (_nameCache.containsKey(senderId)) return _nameCache[senderId]!;
    try {
      final doc = await _firestore.collection('users').doc(senderId).get();
      final name = doc.data()?['name'] as String? ?? 'Someone';
      _nameCache[senderId] = name;
      return name;
    } catch (_) {
      return 'Someone';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'connection_request':
        return Icons.person_add_rounded;
      case 'connection_accepted':
        return Icons.people_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'post_match':
        return Icons.auto_awesome_rounded;
      case 'like':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'connection_request':
        return Colors.blue;
      case 'connection_accepted':
        return Colors.green;
      case 'message':
        return const Color(0xFF016CFF);
      case 'post_match':
        return Colors.purple;
      case 'like':
        return Colors.red;
      default:
        return const Color(0xFF007AFF);
    }
  }

  String _getScreenLabel(String type) {
    switch (type) {
      case 'connection_request':
      case 'connection_accepted':
        return 'Networking';
      case 'message':
        return 'Messages';
      case 'post_match':
      case 'like':
        return 'Nearby';
      default:
        return 'General';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  Future<void> _markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();
    final unread = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            MainNavigationScreen.scaffoldKey.currentState?.openEndDrawer();
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
          'Notifications',
          style: TextStyle(fontFamily: 'Poppins', 
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: const [],
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
            colors: [Color.fromRGBO(64, 64, 64, 1), Color.fromRGBO(0, 0, 0, 1)],
          ),
        ),
        child: uid == null
            ? const Center(
                child: Text(
                  'Please sign in',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white70),
                ),
              )
            : SafeArea(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('notifications')
                      .where('userId', isEqualTo: uid)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading notifications',
                          style: TextStyle(fontFamily: 'Poppins', 
                            color: Colors.red.shade300,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    // Deduplicate by doc.id
                    final seenIds = <String>{};
                    final docs = (snapshot.data?.docs ?? [])
                        .where((doc) => seenIds.add(doc.id))
                        .toList();
                    // Sort client-side to avoid composite index
                    docs.sort((a, b) {
                      final aTime =
                          (a.data() as Map<String, dynamic>)['createdAt']
                              as Timestamp?;
                      final bTime =
                          (b.data() as Map<String, dynamic>)['createdAt']
                              as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your notifications will appear here',
                              style: TextStyle(fontFamily: 'Poppins', 
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final type = data['type'] as String? ?? '';
                        final senderId = data['senderId'] as String?;
                        final title =
                            data['title'] as String? ?? 'Notification';
                        final body = data['body'] as String? ?? '';
                        final isRead = data['read'] as bool? ?? false;
                        final createdAt = data['createdAt'] as Timestamp?;
                        final time = createdAt != null
                            ? timeago.format(createdAt.toDate())
                            : '';

                        return GestureDetector(
                          onTap: () {
                            if (!isRead) _markAsRead(doc.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white24,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: icon + title + screen label (right)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getNotificationColor(
                                          type,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getNotificationIcon(type),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FutureBuilder<String>(
                                            future: _getSenderName(senderId),
                                            builder: (context, snap) {
                                              return Text(
                                                snap.data ?? title,
                                                style: TextStyle(fontFamily: 'Poppins', 
                                                  fontSize: 14,
                                                  fontWeight: isRead
                                                      ? FontWeight.w500
                                                      : FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                          ),
                                          if (time.isNotEmpty)
                                            Text(
                                              time,
                                              style: TextStyle(fontFamily: 'Poppins', 
                                                fontSize: 13,
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                              ),
                                            ),
                                          if (body.isNotEmpty)
                                            Text(
                                              body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontFamily: 'Poppins', 
                                                fontSize: 13,
                                                color: Colors.white.withValues(
                                                  alpha: 0.75,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getNotificationColor(
                                          type,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _getNotificationColor(
                                            type,
                                          ).withValues(alpha: 0.3),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        _getScreenLabel(type),
                                        style: const TextStyle(fontFamily: 'Poppins', 
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
