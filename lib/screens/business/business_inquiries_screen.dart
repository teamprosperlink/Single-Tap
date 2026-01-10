import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/business_model.dart';
import '../../models/business_order_model.dart';
import '../../services/business_service.dart';
import '../../widgets/business/glassmorphic_card.dart';

/// Inquiries management screen for business
/// Simplified from orders - customers send inquiries, business contacts them offline
class BusinessInquiriesScreen extends StatefulWidget {
  final BusinessModel business;
  final String initialFilter;

  const BusinessInquiriesScreen({
    super.key,
    required this.business,
    this.initialFilter = 'All',
  });

  @override
  State<BusinessInquiriesScreen> createState() => _BusinessInquiriesScreenState();
}

class _BusinessInquiriesScreenState extends State<BusinessInquiriesScreen> {
  final BusinessService _businessService = BusinessService();
  late String _selectedFilter;

  // Simplified inquiry filters
  static const List<String> _filters = ['All', 'New', 'Responded', 'Completed', 'Declined'];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Inquiries',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildFilterChips(isDarkMode),
        ),
      ),
      body: StreamBuilder<List<BusinessOrder>>(
        stream: _businessService.watchBusinessOrders(widget.business.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D67D)),
            );
          }

          final allInquiries = snapshot.data ?? [];
          final inquiries = _filterInquiries(allInquiries);

          if (allInquiries.isEmpty) {
            return _buildEmptyState(isDarkMode);
          }

          if (inquiries.isEmpty) {
            return _buildNoResultsState(isDarkMode);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            color: const Color(0xFF00D67D),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inquiries.length,
              itemBuilder: (context, index) {
                final inquiry = inquiries[index];
                return _InquiryCard(
                  inquiry: inquiry,
                  isDarkMode: isDarkMode,
                  onTap: () => _showInquiryDetails(inquiry),
                  onCall: () => _makePhoneCall(inquiry),
                  onWhatsApp: () => _openWhatsApp(inquiry),
                  onResponded: () => _markAsResponded(inquiry),
                  onComplete: () => _markAsCompleted(inquiry),
                  onDecline: () => _confirmDecline(inquiry),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedFilter = filter);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D67D).withValues(alpha: 0.2)
                          : (isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.7)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D67D)
                            : (isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3)),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Color(0xFF00D67D),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF00D67D)
                                : (isDarkMode ? Colors.white70 : Colors.grey[700]),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<BusinessOrder> _filterInquiries(List<BusinessOrder> inquiries) {
    switch (_selectedFilter) {
      case 'New':
        return inquiries.where((i) =>
          i.status == OrderStatus.newOrder ||
          i.status == OrderStatus.pending
        ).toList();
      case 'Responded':
        return inquiries.where((i) =>
          i.status == OrderStatus.accepted ||
          i.status == OrderStatus.inProgress
        ).toList();
      case 'Completed':
        return inquiries.where((i) =>
          i.status == OrderStatus.completed ||
          i.status == OrderStatus.reviewed
        ).toList();
      case 'Declined':
        return inquiries.where((i) =>
          i.status == OrderStatus.cancelled
        ).toList();
      default:
        return inquiries;
    }
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: GlassmorphicCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D67D).withValues(alpha: 0.2),
                      const Color(0xFF00D67D).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00D67D).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Color(0xFF00D67D),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Inquiries Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When customers are interested in your services,\ntheir inquiries will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedFilter inquiries found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _selectedFilter = 'All'),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  void _showInquiryDetails(BusinessOrder inquiry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InquiryDetailsSheet(
        inquiry: inquiry,
        onCall: () => _makePhoneCall(inquiry),
        onWhatsApp: () => _openWhatsApp(inquiry),
        onResponded: () {
          Navigator.pop(context);
          _markAsResponded(inquiry);
        },
        onComplete: () {
          Navigator.pop(context);
          _markAsCompleted(inquiry);
        },
        onDecline: () {
          Navigator.pop(context);
          _confirmDecline(inquiry);
        },
      ),
    );
  }

  Future<void> _makePhoneCall(BusinessOrder inquiry) async {
    final phone = inquiry.customerPhone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(BusinessOrder inquiry) async {
    final phone = inquiry.customerPhone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number available')),
        );
      }
      return;
    }

    // Remove any non-digit characters except + for international format
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message = 'Hi ${inquiry.customerName}, regarding your inquiry about ${inquiry.serviceName}...';
    final encodedMessage = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAsResponded(BusinessOrder inquiry) async {
    final success = await _businessService.updateOrderStatus(
      inquiry.id,
      OrderStatus.accepted,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as Responded'),
          backgroundColor: Color(0xFF00D67D),
        ),
      );
    }
  }

  Future<void> _markAsCompleted(BusinessOrder inquiry) async {
    final success = await _businessService.updateOrderStatus(
      inquiry.id,
      OrderStatus.completed,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as Completed'),
          backgroundColor: Color(0xFF00D67D),
        ),
      );
    }
  }

  void _confirmDecline(BusinessOrder inquiry) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
        title: const Text('Decline Inquiry?'),
        content: const Text(
          'Are you sure you want to decline this inquiry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _businessService.updateOrderStatus(
                inquiry.id,
                OrderStatus.cancelled,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inquiry declined')),
                );
              }
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Inquiry card widget with glassmorphic design
class _InquiryCard extends StatelessWidget {
  final BusinessOrder inquiry;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onResponded;
  final VoidCallback onComplete;
  final VoidCallback onDecline;

  const _InquiryCard({
    required this.inquiry,
    required this.isDarkMode,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
    required this.onResponded,
    required this.onComplete,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        onTap: onTap,
        showGlow: _isNew,
        glowColor: Colors.orange,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                // Customer avatar with glow for new
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _isNew ? [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                    backgroundImage: inquiry.customerPhoto != null
                        ? NetworkImage(inquiry.customerPhoto!)
                        : null,
                    child: inquiry.customerPhoto == null
                        ? Text(
                            inquiry.customerName.isNotEmpty
                                ? inquiry.customerName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D67D),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inquiry.customerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Interested in: ${inquiry.serviceName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),

            // Customer message
            if (inquiry.customerNotes != null && inquiry.customerNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inquiry.customerNotes!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Time
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(inquiry.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            ),

            // Action buttons
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Contact buttons
                _buildContactButton(
                  icon: Icons.phone,
                  label: 'Call',
                  color: Colors.green,
                  onTap: onCall,
                ),
                const SizedBox(width: 8),
                _buildContactButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: onWhatsApp,
                ),
                const Spacer(),
                // Status action
                if (_isNew)
                  _buildActionButton(
                    icon: Icons.check,
                    label: 'Responded',
                    color: Colors.blue,
                    onTap: onResponded,
                  )
                else if (_isResponded)
                  _buildActionButton(
                    icon: Icons.done_all,
                    label: 'Complete',
                    color: const Color(0xFF00D67D),
                    onTap: onComplete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isNew =>
      inquiry.status == OrderStatus.newOrder ||
      inquiry.status == OrderStatus.pending;

  bool get _isResponded =>
      inquiry.status == OrderStatus.accepted ||
      inquiry.status == OrderStatus.inProgress;

  Widget _buildStatusChip() {
    final status = _getInquiryStatus();
    final color = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getInquiryStatus() {
    switch (inquiry.status) {
      case OrderStatus.newOrder:
      case OrderStatus.pending:
        return 'New';
      case OrderStatus.accepted:
      case OrderStatus.inProgress:
        return 'Responded';
      case OrderStatus.completed:
      case OrderStatus.reviewed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Declined';
    }
  }

  Color _getStatusColor() {
    switch (inquiry.status) {
      case OrderStatus.newOrder:
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
      case OrderStatus.inProgress:
        return Colors.blue;
      case OrderStatus.completed:
      case OrderStatus.reviewed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Inquiry details bottom sheet with glassmorphic design
class _InquiryDetailsSheet extends StatelessWidget {
  final BusinessOrder inquiry;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onResponded;
  final VoidCallback onComplete;
  final VoidCallback onDecline;

  const _InquiryDetailsSheet({
    required this.inquiry,
    required this.onCall,
    required this.onWhatsApp,
    required this.onResponded,
    required this.onComplete,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer section
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                        backgroundImage: inquiry.customerPhoto != null
                            ? NetworkImage(inquiry.customerPhoto!)
                            : null,
                        child: inquiry.customerPhoto == null
                            ? Text(
                                inquiry.customerName.isNotEmpty
                                    ? inquiry.customerName[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D67D),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inquiry.customerName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (inquiry.customerPhone != null)
                              Text(
                                inquiry.customerPhone!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildStatusChip(isDarkMode),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildLargeContactButton(
                          icon: Icons.phone,
                          label: 'Call',
                          color: Colors.green,
                          onTap: onCall,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLargeContactButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: onWhatsApp,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Service interested in
                  _buildInfoSection(
                    title: 'Interested In',
                    isDarkMode: isDarkMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inquiry.serviceName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (inquiry.serviceDescription != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            inquiry.serviceDescription!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer message
                  if (inquiry.customerNotes != null && inquiry.customerNotes!.isNotEmpty) ...[
                    _buildInfoSection(
                      title: 'Customer Message',
                      isDarkMode: isDarkMode,
                      child: Text(
                        inquiry.customerNotes!,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Inquiry time
                  _buildInfoSection(
                    title: 'Received',
                    isDarkMode: isDarkMode,
                    child: Text(
                      _formatDateTime(inquiry.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2D2D44) : Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_isNew) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
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
                        onPressed: onResponded,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D67D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Mark as Responded'),
                      ),
                    ),
                  ] else if (_isResponded) ...[
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
                        ),
                        child: const Text('Mark as Completed'),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getInquiryStatus(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  bool get _isNew =>
      inquiry.status == OrderStatus.newOrder ||
      inquiry.status == OrderStatus.pending;

  bool get _isResponded =>
      inquiry.status == OrderStatus.accepted ||
      inquiry.status == OrderStatus.inProgress;

  String _getInquiryStatus() {
    switch (inquiry.status) {
      case OrderStatus.newOrder:
      case OrderStatus.pending:
        return 'New';
      case OrderStatus.accepted:
      case OrderStatus.inProgress:
        return 'Responded';
      case OrderStatus.completed:
      case OrderStatus.reviewed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Declined';
    }
  }

  Color _getStatusColor() {
    switch (inquiry.status) {
      case OrderStatus.newOrder:
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
      case OrderStatus.inProgress:
        return Colors.blue;
      case OrderStatus.completed:
      case OrderStatus.reviewed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  Widget _buildStatusChip(bool isDarkMode) {
    final status = _getInquiryStatus();
    final color = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLargeContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required bool isDarkMode,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $period';
  }
}
