import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/other providers/app_providers.dart';
import '../../services/group_chat_service.dart';
import '../../res/utils/photo_url_helper.dart';
import '../../res/config/app_colors.dart';
import '../../widgets/other widgets/glass_text_field.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupChatService _groupChatService = GroupChatService();

  // Helper getter for current user ID from provider
  String? get _currentUserId => ref.read(currentUserIdProvider);

  final Set<String> _selectedUserIds = {};
  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final groupId = await _groupChatService.createGroup(
        groupName: groupName,
        memberIds: _selectedUserIds.toList(),
      );

      if (groupId != null && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, groupId);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.splashDark1,
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 1),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: const Text(
              'New Group',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isCreating ? null : _createGroup,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: SafeArea(
          child: Column(
        children: [
          // Group name + Search in one row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: GlassTextField(
                    controller: _groupNameController,
                    hintText: 'Group name',
                    prefixIcon: const Icon(
                      Icons.group,
                      color: Colors.white70,
                      size: 20,
                    ),
                    borderRadius: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassTextField(
                    controller: _searchController,
                    hintText: 'Search users...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white70,
                      size: 20,
                    ),
                    borderRadius: 12,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Selected members chips
          if (_selectedUserIds.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedUserIds.map((userId) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(userId).get(),
                    builder: (context, snapshot) {
                      final name = snapshot.data?.get('name') ?? 'User';
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white70),
                          onDeleted: () {
                            setState(() {
                              _selectedUserIds.remove(userId);
                            });
                          },
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),

          // User list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs
                    .where((doc) => doc.id != currentUserId)
                    .where((doc) {
                      if (_searchQuery.isEmpty) return true;
                      final name =
                          (doc.data() as Map<String, dynamic>)['name']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      return name.contains(_searchQuery);
                    })
                    .toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData =
                        users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;
                    final name = userData['name'] ?? 'Unknown';
                    final photoUrl = userData['photoUrl'];
                    final isSelected = _selectedUserIds.contains(userId);

                    return ListTile(
                      leading: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundImage: PhotoUrlHelper.isValidUrl(photoUrl)
                                  ? CachedNetworkImageProvider(photoUrl)
                                  : null,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              child: !PhotoUrlHelper.isValidUrl(photoUrl)
                                  ? Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.circle_outlined,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(userId);
                          } else {
                            _selectedUserIds.add(userId);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
