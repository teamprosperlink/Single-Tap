import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'safe_circle_avatar.dart';

/// Dialog to select participants for group video call (WhatsApp style)
class SelectParticipantsDialog extends StatefulWidget {
  final String currentUserId;
  final int maxParticipants;

  const SelectParticipantsDialog({
    super.key,
    required this.currentUserId,
    this.maxParticipants = 7, // Max 7 other users + self = 8 total
  });

  @override
  State<SelectParticipantsDialog> createState() => _SelectParticipantsDialogState();
}

class _SelectParticipantsDialogState extends State<SelectParticipantsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _selectedUserIds = {};
  List<UserProfile> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      // Load user's connections/contacts
      final snapshot = await _firestore
          .collection('connection_requests')
          .where('status', isEqualTo: 'accepted')
          .get();

      final Set<String> contactIds = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        final receiverId = data['receiverId'] as String?;

        if (senderId == widget.currentUserId && receiverId != null) {
          contactIds.add(receiverId);
        } else if (receiverId == widget.currentUserId && senderId != null) {
          contactIds.add(senderId);
        }
      }

      // Fetch user profiles
      if (contactIds.isNotEmpty) {
        final userDocs = await Future.wait(
          contactIds.map((id) => _firestore.collection('users').doc(id).get()),
        );

        _contacts = userDocs
            .where((doc) => doc.exists)
            .map((doc) => UserProfile.fromFirestore(doc))
            .toList();

        _contacts.sort((a, b) => a.name.compareTo(b.name));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        if (_selectedUserIds.length < widget.maxParticipants) {
          _selectedUserIds.add(userId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum ${widget.maxParticipants} participants allowed'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _startCall() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one participant'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedUsers = _contacts
        .where((user) => _selectedUserIds.contains(user.uid))
        .map((user) => {
              'userId': user.uid,
              'name': user.name,
              'photoUrl': user.photoUrl,
            })
        .toList();

    Navigator.of(context).pop(selectedUsers);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Participants',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Selected count indicator
            if (_selectedUserIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.green.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedUserIds.length} participant${_selectedUserIds.length == 1 ? "" : "s"} selected',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Contacts list
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _contacts.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No contacts found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final user = _contacts[index];
                            final isSelected = _selectedUserIds.contains(user.uid);

                            return ListTile(
                              leading: Stack(
                                children: [
                                  SafeCircleAvatar(
                                    photoUrl: user.photoUrl,
                                    radius: 24,
                                    name: user.name,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: user.isOnline
                                  ? const Text(
                                      'Online',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(user.uid),
                                activeColor: Colors.green,
                                shape: const CircleBorder(),
                              ),
                              onTap: () => _toggleSelection(user.uid),
                            );
                          },
                        ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedUserIds.isEmpty ? null : _startCall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Start Call',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedUserIds.isEmpty ? Colors.grey : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
