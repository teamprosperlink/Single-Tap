import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/inquiry_model.dart';
import '../../services/inquiry_service.dart';
import '../../res/utils/photo_url_helper.dart';

/// Screen for professionals to manage their inquiries
class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({super.key});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InquiryService _inquiryService = InquiryService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: Text(
          'Inquiries',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00D67D),
          unselectedLabelColor: isDarkMode ? Colors.white54 : Colors.grey[600],
          indicatorColor: const Color(0xFF00D67D),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInquiryList(null, isDarkMode),
          _buildInquiryList(InquiryStatus.pending, isDarkMode),
          _buildActiveInquiriesList(isDarkMode),
          _buildInquiryList(InquiryStatus.completed, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildInquiryList(InquiryStatus? status, bool isDarkMode) {
    return StreamBuilder<List<InquiryModel>>(
      stream: _inquiryService.watchReceivedInquiries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        var inquiries = snapshot.data ?? [];

        // Filter by status if specified
        if (status != null) {
          inquiries = inquiries.where((i) => i.status == status).toList();
        }

        if (inquiries.isEmpty) {
          return _buildEmptyState(status, isDarkMode);
        }

        return RefreshIndicator(
          onRefresh: () async {
            // StreamBuilder handles refresh
          },
          color: const Color(0xFF00D67D),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inquiries.length,
            itemBuilder: (context, index) {
              return _buildInquiryCard(inquiries[index], isDarkMode);
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveInquiriesList(bool isDarkMode) {
    return StreamBuilder<List<InquiryModel>>(
      stream: _inquiryService.watchReceivedInquiries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D67D)),
          );
        }

        final inquiries = (snapshot.data ?? []).where((i) => i.isActive).toList();

        if (inquiries.isEmpty) {
          return _buildEmptyState(null, isDarkMode, customMessage: 'No active inquiries');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inquiries.length,
          itemBuilder: (context, index) {
            return _buildInquiryCard(inquiries[index], isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildInquiryCard(InquiryModel inquiry, bool isDarkMode) {
    final statusColor = _getStatusColor(inquiry.status);

    return GestureDetector(
      onTap: () => _showInquiryDetail(inquiry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Client avatar
                  Builder(
                    builder: (context) {
                      final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(inquiry.clientPhoto);
                      final initial = inquiry.clientName.isNotEmpty ? inquiry.clientName[0].toUpperCase() : '?';

                      Widget buildFallbackAvatar() {
                        return CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Color(0xFF00D67D),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        );
                      }

                      if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                        return buildFallbackAvatar();
                      }

                      return ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: fixedPhotoUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => buildFallbackAvatar(),
                          errorWidget: (context, url, error) {
                            if (error.toString().contains('429')) {
                              PhotoUrlHelper.markAsRateLimited(url);
                            }
                            return buildFallbackAvatar();
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                inquiry.clientName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!inquiry.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00D67D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (inquiry.serviceName != null)
                          Text(
                            inquiry.serviceName!,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      inquiry.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Message preview
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inquiry.message,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Footer: budget, timeline, date
                  Row(
                    children: [
                      if (inquiry.budget != null) ...[
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        Text(
                          inquiry.budget!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (inquiry.timeline != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          inquiry.timeline!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        inquiry.formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick actions for pending inquiries
            if (inquiry.status == InquiryStatus.pending)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineInquiry(inquiry),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          side: BorderSide(color: Colors.red[400]!),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _respondToInquiry(inquiry),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D67D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Respond'),
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

  Color _getStatusColor(InquiryStatus status) {
    switch (status) {
      case InquiryStatus.pending:
        return Colors.orange;
      case InquiryStatus.responded:
        return Colors.blue;
      case InquiryStatus.negotiating:
        return Colors.purple;
      case InquiryStatus.accepted:
        return Colors.green;
      case InquiryStatus.declined:
        return Colors.red;
      case InquiryStatus.completed:
        return const Color(0xFF00D67D);
      case InquiryStatus.cancelled:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(InquiryStatus? status, bool isDarkMode, {String? customMessage}) {
    String title;
    String subtitle;
    IconData icon;

    switch (status) {
      case InquiryStatus.pending:
        title = 'No pending inquiries';
        subtitle = 'You\'re all caught up!';
        icon = Icons.inbox_outlined;
        break;
      case InquiryStatus.completed:
        title = 'No completed inquiries';
        subtitle = 'Completed projects will appear here';
        icon = Icons.check_circle_outline;
        break;
      default:
        title = customMessage ?? 'No inquiries yet';
        subtitle = 'Inquiries from clients will appear here';
        icon = Icons.mail_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _showInquiryDetail(InquiryModel inquiry) {
    // Mark as read
    if (!inquiry.isRead) {
      _inquiryService.markAsRead(inquiry.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InquiryDetailSheet(
        inquiry: inquiry,
        onRespond: () => _respondToInquiry(inquiry),
        onDecline: () => _declineInquiry(inquiry),
        onComplete: () => _completeInquiry(inquiry),
      ),
    );
  }

  void _respondToInquiry(InquiryModel inquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RespondSheet(inquiry: inquiry),
    );
  }

  Future<void> _declineInquiry(InquiryModel inquiry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Decline Inquiry?'),
        content: Text(
          'Are you sure you want to decline the inquiry from ${inquiry.clientName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Decline', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _inquiryService.updateStatus(inquiry.id, InquiryStatus.declined);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inquiry declined')),
        );
      }
    }
  }

  Future<void> _completeInquiry(InquiryModel inquiry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2D44)
            : Colors.white,
        title: const Text('Mark as Completed?'),
        content: const Text('This will mark the project as successfully completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Complete',
              style: TextStyle(color: Color(0xFF00D67D)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _inquiryService.updateStatus(inquiry.id, InquiryStatus.completed);
      if (mounted) {
        Navigator.pop(context); // Close detail sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project marked as completed!'),
            backgroundColor: Color(0xFF00D67D),
          ),
        );
      }
    }
  }
}

/// Detail sheet for viewing inquiry
class _InquiryDetailSheet extends StatelessWidget {
  final InquiryModel inquiry;
  final VoidCallback onRespond;
  final VoidCallback onDecline;
  final VoidCallback onComplete;

  const _InquiryDetailSheet({
    required this.inquiry,
    required this.onRespond,
    required this.onDecline,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final fixedPhotoUrl = PhotoUrlHelper.fixGooglePhotoUrl(inquiry.clientPhoto);
                        final initial = inquiry.clientName.isNotEmpty ? inquiry.clientName[0].toUpperCase() : '?';

                        Widget buildFallbackAvatar() {
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Color(0xFF00D67D),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          );
                        }

                        if (fixedPhotoUrl == null || fixedPhotoUrl.isEmpty) {
                          return buildFallbackAvatar();
                        }

                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: fixedPhotoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => buildFallbackAvatar(),
                            errorWidget: (context, url, error) {
                              if (error.toString().contains('429')) {
                                PhotoUrlHelper.markAsRateLimited(url);
                              }
                              return buildFallbackAvatar();
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inquiry.clientName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (inquiry.serviceName != null)
                            Text(
                              inquiry.serviceName!,
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message
                      _buildSection('Message', inquiry.message, isDarkMode),

                      if (inquiry.projectDescription != null &&
                          inquiry.projectDescription!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSection(
                          'Project Details',
                          inquiry.projectDescription!,
                          isDarkMode,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Budget & Timeline
                      Row(
                        children: [
                          if (inquiry.budget != null)
                            Expanded(
                              child: _buildInfoCard(
                                Icons.attach_money,
                                'Budget',
                                inquiry.budget!,
                                isDarkMode,
                              ),
                            ),
                          if (inquiry.budget != null && inquiry.timeline != null)
                            const SizedBox(width: 12),
                          if (inquiry.timeline != null)
                            Expanded(
                              child: _buildInfoCard(
                                Icons.schedule,
                                'Timeline',
                                inquiry.timeline!,
                                isDarkMode,
                              ),
                            ),
                        ],
                      ),

                      // Messages thread
                      if (inquiry.messages.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Conversation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...inquiry.messages.map((msg) => _buildMessageBubble(
                              msg,
                              isDarkMode,
                            )),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[50],
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? Colors.white10 : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: _buildActions(context, isDarkMode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDarkMode ? Colors.white38 : Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(InquiryMessage msg, bool isDarkMode) {
    final isFromPro = msg.isFromProfessional;

    return Align(
      alignment: isFromPro ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromPro
              ? const Color(0xFF00D67D).withValues(alpha: 0.15)
              : (isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.senderName} • ${_formatTime(msg.timestamp)}',
              style: TextStyle(
                fontSize: 10,
                color: isDarkMode ? Colors.white38 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  Widget _buildActions(BuildContext context, bool isDarkMode) {
    switch (inquiry.status) {
      case InquiryStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDecline();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[400],
                  side: BorderSide(color: Colors.red[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRespond();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Respond'),
              ),
            ),
          ],
        );

      case InquiryStatus.responded:
      case InquiryStatus.negotiating:
      case InquiryStatus.accepted:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRespond();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00D67D),
                  side: const BorderSide(color: Color(0xFF00D67D)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send Message'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D67D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text('Mark Complete'),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

/// Sheet for responding to an inquiry
class _RespondSheet extends StatefulWidget {
  final InquiryModel inquiry;

  const _RespondSheet({required this.inquiry});

  @override
  State<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends State<_RespondSheet> {
  final _responseController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController();
  final InquiryService _inquiryService = InquiryService();
  bool _isLoading = false;

  @override
  void dispose() {
    _responseController.dispose();
    _priceController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  Future<void> _sendResponse() async {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a response')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _inquiryService.respondToInquiry(
        widget.inquiry.id,
        response: _responseController.text.trim(),
        quotedPrice: _priceController.text.trim().isNotEmpty
            ? _priceController.text.trim()
            : null,
        estimatedDelivery: _deliveryController.text.trim().isNotEmpty
            ? _deliveryController.text.trim()
            : null,
      );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response sent!'),
            backgroundColor: Color(0xFF00D67D),
          ),
        );
      } else {
        throw Exception('Failed to send response');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Respond to ${widget.inquiry.clientName}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              // Response field
              TextField(
                controller: _responseController,
                maxLines: 4,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Write your response...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Price & Delivery
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Quote price (optional)',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white38 : Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _deliveryController,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Delivery time',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white38 : Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.schedule,
                          color: isDarkMode ? Colors.white38 : Colors.grey[500],
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendResponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send Response',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
