import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';

/// Membership type
enum MembershipType {
  monthly,
  quarterly,
  halfYearly,
  yearly,
  classPass,
  dropIn;

  String get displayName {
    switch (this) {
      case MembershipType.monthly:
        return 'Monthly';
      case MembershipType.quarterly:
        return 'Quarterly';
      case MembershipType.halfYearly:
        return 'Half-Yearly';
      case MembershipType.yearly:
        return 'Yearly';
      case MembershipType.classPass:
        return 'Class Pack';
      case MembershipType.dropIn:
        return 'Day Pass';
    }
  }

  IconData get icon {
    switch (this) {
      case MembershipType.monthly:
        return Icons.calendar_month;
      case MembershipType.quarterly:
        return Icons.date_range;
      case MembershipType.halfYearly:
        return Icons.event;
      case MembershipType.yearly:
        return Icons.calendar_today;
      case MembershipType.classPass:
        return Icons.confirmation_number;
      case MembershipType.dropIn:
        return Icons.schedule;
    }
  }

  static MembershipType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'quarterly':
        return MembershipType.quarterly;
      case 'halfyearly':
      case 'half_yearly':
        return MembershipType.halfYearly;
      case 'yearly':
        return MembershipType.yearly;
      case 'classpass':
      case 'class_pass':
        return MembershipType.classPass;
      case 'dropin':
      case 'drop_in':
        return MembershipType.dropIn;
      default:
        return MembershipType.monthly;
    }
  }
}

/// Membership status
enum MembershipStatus {
  active,
  expired,
  cancelled,
  paused,
  pending;

  String get displayName {
    switch (this) {
      case MembershipStatus.active:
        return 'Active';
      case MembershipStatus.expired:
        return 'Expired';
      case MembershipStatus.cancelled:
        return 'Cancelled';
      case MembershipStatus.paused:
        return 'Paused';
      case MembershipStatus.pending:
        return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case MembershipStatus.active:
        return Colors.green;
      case MembershipStatus.expired:
        return Colors.red;
      case MembershipStatus.cancelled:
        return Colors.grey;
      case MembershipStatus.paused:
        return Colors.orange;
      case MembershipStatus.pending:
        return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case MembershipStatus.active:
        return Icons.check_circle;
      case MembershipStatus.expired:
        return Icons.error;
      case MembershipStatus.cancelled:
        return Icons.cancel;
      case MembershipStatus.paused:
        return Icons.pause_circle;
      case MembershipStatus.pending:
        return Icons.pending;
    }
  }

  static MembershipStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'expired':
        return MembershipStatus.expired;
      case 'cancelled':
        return MembershipStatus.cancelled;
      case 'paused':
        return MembershipStatus.paused;
      case 'pending':
        return MembershipStatus.pending;
      default:
        return MembershipStatus.active;
    }
  }
}

/// Membership model
class MembershipModel {
  final String id;
  final String businessId;
  final String memberId;
  final String memberName;
  final String? memberEmail;
  final String? memberPhone;
  final String? memberPhoto;
  final MembershipType type;
  final MembershipStatus status;
  final double price;
  final double? amountPaid;
  final int? classesIncluded; // For class pass
  final int? classesRemaining;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final bool autoRenew;
  final String? notes;
  final DateTime createdAt;

  MembershipModel({
    required this.id,
    required this.businessId,
    required this.memberId,
    required this.memberName,
    this.memberEmail,
    this.memberPhone,
    this.memberPhoto,
    required this.type,
    this.status = MembershipStatus.pending,
    required this.price,
    this.amountPaid,
    this.classesIncluded,
    this.classesRemaining,
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.autoRenew = true,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MembershipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MembershipModel(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      memberEmail: data['memberEmail'],
      memberPhone: data['memberPhone'],
      memberPhoto: data['memberPhoto'],
      type: MembershipType.fromString(data['type']),
      status: MembershipStatus.fromString(data['status']),
      price: (data['price'] ?? 0).toDouble(),
      amountPaid: data['amountPaid']?.toDouble(),
      classesIncluded: data['classesIncluded'],
      classesRemaining: data['classesRemaining'],
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      nextBillingDate: data['nextBillingDate'] != null
          ? (data['nextBillingDate'] as Timestamp).toDate()
          : null,
      autoRenew: data['autoRenew'] ?? true,
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'memberId': memberId,
      'memberName': memberName,
      'memberEmail': memberEmail,
      'memberPhone': memberPhone,
      'memberPhoto': memberPhoto,
      'type': type.name,
      'status': status.name,
      'price': price,
      'amountPaid': amountPaid,
      'classesIncluded': classesIncluded,
      'classesRemaining': classesRemaining,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextBillingDate':
          nextBillingDate != null ? Timestamp.fromDate(nextBillingDate!) : null,
      'autoRenew': autoRenew,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  MembershipModel copyWith({
    String? id,
    String? businessId,
    String? memberId,
    String? memberName,
    String? memberEmail,
    String? memberPhone,
    String? memberPhoto,
    MembershipType? type,
    MembershipStatus? status,
    double? price,
    double? amountPaid,
    int? classesIncluded,
    int? classesRemaining,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    bool? autoRenew,
    String? notes,
    DateTime? createdAt,
  }) {
    return MembershipModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      memberEmail: memberEmail ?? this.memberEmail,
      memberPhone: memberPhone ?? this.memberPhone,
      memberPhoto: memberPhoto ?? this.memberPhoto,
      type: type ?? this.type,
      status: status ?? this.status,
      price: price ?? this.price,
      amountPaid: amountPaid ?? this.amountPaid,
      classesIncluded: classesIncluded ?? this.classesIncluded,
      classesRemaining: classesRemaining ?? this.classesRemaining,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      autoRenew: autoRenew ?? this.autoRenew,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpiringSoon {
    if (endDate == null) return false;
    final daysUntilExpiry = endDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 7;
  }

  int? get daysRemaining {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }
}

/// Fitness memberships tab
class FitnessMembershipsTab extends StatefulWidget {
  final BusinessModel business;

  const FitnessMembershipsTab({super.key, required this.business});

  @override
  State<FitnessMembershipsTab> createState() => _FitnessMembershipsTabState();
}

class _FitnessMembershipsTabState extends State<FitnessMembershipsTab> {
  String _selectedFilter = 'Active';

  final List<String> _filters = [
    'Active',
    'Expiring Soon',
    'Paused',
    'Expired',
    'All',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary cards
        Container(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseProvider.firestore
                .collection('businesses')
                .doc(widget.business.id)
                .collection('memberships')
                .snapshots(),
            builder: (context, snapshot) {
              final memberships = snapshot.data?.docs ?? [];
              final active = memberships
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['status'] == 'active')
                  .length;
              final expiring = memberships.where((d) {
                final data = d.data() as Map<String, dynamic>;
                if (data['status'] != 'active' || data['endDate'] == null) {
                  return false;
                }
                final endDate = (data['endDate'] as Timestamp).toDate();
                final days = endDate.difference(DateTime.now()).inDays;
                return days >= 0 && days <= 7;
              }).length;

              return Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.people,
                      value: active.toString(),
                      label: 'Active Members',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.warning,
                      value: expiring.toString(),
                      label: 'Expiring Soon',
                      color: Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Filter bar
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = filter);
                  },
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
        ),

        // Memberships list
        Expanded(
          child: _buildMembershipsList(),
        ),
      ],
    );
  }

  Widget _buildMembershipsList() {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('memberships');

    if (_selectedFilter == 'Active') {
      query = query.where('status', isEqualTo: 'active');
    } else if (_selectedFilter == 'Paused') {
      query = query.where('status', isEqualTo: 'paused');
    } else if (_selectedFilter == 'Expired') {
      query = query.where('status', isEqualTo: 'expired');
    }

    query = query.orderBy('startDate', descending: true).limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var memberships = snapshot.data!.docs
            .map((doc) => MembershipModel.fromFirestore(doc))
            .toList();

        // Client-side filter for "Expiring Soon"
        if (_selectedFilter == 'Expiring Soon') {
          memberships =
              memberships.where((m) => m.isExpiringSoon).toList();
        }

        if (memberships.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: memberships.length,
          itemBuilder: (context, index) {
            return _MembershipCard(
              membership: memberships[index],
              onTap: () => _showMembershipDetails(memberships[index]),
              onStatusChange: (status) =>
                  _updateStatus(memberships[index], status),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No memberships found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Members will appear here'
                : 'No ${_selectedFilter.toLowerCase()} memberships',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    MembershipModel membership,
    MembershipStatus newStatus,
  ) async {
    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('memberships')
          .doc(membership.id)
          .update({'status': newStatus.name});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMembershipDetails(MembershipModel membership) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MembershipDetailsSheet(
        membership: membership,
        businessId: widget.business.id,
        onUpdate: () => setState(() {}),
      ),
    );
  }
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Membership card widget
class _MembershipCard extends StatelessWidget {
  final MembershipModel membership;
  final VoidCallback onTap;
  final Function(MembershipStatus) onStatusChange;

  const _MembershipCard({
    required this.membership,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor.withValues(alpha: 0.2),
                    backgroundImage: membership.memberPhoto != null
                        ? NetworkImage(membership.memberPhoto!)
                        : null,
                    child: membership.memberPhoto == null
                        ? Text(
                            membership.memberName.isNotEmpty
                                ? membership.memberName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          membership.memberName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              membership.type.icon,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              membership.type.displayName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: membership.status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          membership.status.icon,
                          size: 16,
                          color: membership.status.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          membership.status.displayName,
                          style: TextStyle(
                            color: membership.status.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),

              // Info row
              Row(
                children: [
                  // Dates
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membership Period',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          membership.endDate != null
                              ? '${dateFormat.format(membership.startDate)} - ${dateFormat.format(membership.endDate!)}'
                              : 'Started ${dateFormat.format(membership.startDate)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (membership.daysRemaining != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            membership.daysRemaining! <= 0
                                ? 'Expired'
                                : '${membership.daysRemaining} days remaining',
                            style: TextStyle(
                              color: membership.isExpiringSoon
                                  ? Colors.orange
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: membership.isExpiringSoon
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Classes remaining (for class pass)
                  if (membership.type == MembershipType.classPass &&
                      membership.classesRemaining != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${membership.classesRemaining}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'classes left',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '\$${membership.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                ],
              ),

              // Warning for expiring memberships
              if (membership.isExpiringSoon) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          membership.autoRenew
                              ? 'Auto-renews in ${membership.daysRemaining} days'
                              : 'Expires in ${membership.daysRemaining} days - Contact to renew',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Membership details sheet
class _MembershipDetailsSheet extends StatefulWidget {
  final MembershipModel membership;
  final String businessId;
  final VoidCallback onUpdate;

  const _MembershipDetailsSheet({
    required this.membership,
    required this.businessId,
    required this.onUpdate,
  });

  @override
  State<_MembershipDetailsSheet> createState() =>
      _MembershipDetailsSheetState();
}

class _MembershipDetailsSheetState extends State<_MembershipDetailsSheet> {
  late MembershipModel _membership;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _membership = widget.membership;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Member header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: primaryColor.withValues(alpha: 0.2),
                      backgroundImage: _membership.memberPhoto != null
                          ? NetworkImage(_membership.memberPhoto!)
                          : null,
                      child: _membership.memberPhoto == null
                          ? Text(
                              _membership.memberName.isNotEmpty
                                  ? _membership.memberName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
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
                            _membership.memberName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_membership.memberEmail != null)
                            Text(
                              _membership.memberEmail!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          if (_membership.memberPhone != null)
                            Text(
                              _membership.memberPhone!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Membership type card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _membership.type.icon,
                        color: primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_membership.type.displayName} Membership',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '\$${_membership.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _membership.status.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _membership.status.icon,
                              size: 16,
                              color: _membership.status.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _membership.status.displayName,
                              style: TextStyle(
                                color: _membership.status.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Dates section
                _buildSection(
                  'Membership Period',
                  Column(
                    children: [
                      _buildInfoRow(
                          'Start Date', dateFormat.format(_membership.startDate)),
                      if (_membership.endDate != null)
                        _buildInfoRow(
                            'End Date', dateFormat.format(_membership.endDate!)),
                      if (_membership.nextBillingDate != null)
                        _buildInfoRow('Next Billing',
                            dateFormat.format(_membership.nextBillingDate!)),
                      _buildInfoRow(
                        'Auto-Renew',
                        _membership.autoRenew ? 'Yes' : 'No',
                        valueColor:
                            _membership.autoRenew ? Colors.green : Colors.grey,
                      ),
                    ],
                  ),
                ),

                // Class pass info
                if (_membership.type == MembershipType.classPass) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    'Class Pass',
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Classes Remaining',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              '${_membership.classesRemaining ?? 0} / ${_membership.classesIncluded ?? 0}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _membership.classesIncluded != null &&
                                    _membership.classesIncluded! > 0
                                ? (_membership.classesRemaining ?? 0) /
                                    _membership.classesIncluded!
                                : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: (_membership.classesRemaining ?? 0) > 0
                                    ? () => _updateClasses(-1)
                                    : null,
                                icon: const Icon(Icons.remove),
                                label: const Text('Use Class'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateClasses(1),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Class'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Payment info
                const SizedBox(height: 24),
                _buildSection(
                  'Payment',
                  Column(
                    children: [
                      _buildInfoRow(
                          'Price', '\$${_membership.price.toStringAsFixed(2)}'),
                      _buildInfoRow(
                        'Paid',
                        '\$${(_membership.amountPaid ?? 0).toStringAsFixed(2)}',
                      ),
                      _buildInfoRow(
                        'Balance',
                        '\$${(_membership.price - (_membership.amountPaid ?? 0)).toStringAsFixed(2)}',
                        valueColor:
                            _membership.price > (_membership.amountPaid ?? 0)
                                ? Colors.red
                                : Colors.green,
                      ),
                    ],
                  ),
                ),

                // Notes
                if (_membership.notes != null &&
                    _membership.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSection(
                    'Notes',
                    Text(_membership.notes!),
                  ),
                ],

                // Status actions
                if (_membership.status == MembershipStatus.active) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _updateStatus(MembershipStatus.paused),
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _updateStatus(MembershipStatus.cancelled),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_membership.status == MembershipStatus.paused) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _updateStatus(MembershipStatus.active),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume Membership'),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(MembershipStatus newStatus) async {
    setState(() => _isLoading = true);

    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('memberships')
          .doc(_membership.id)
          .update({'status': newStatus.name});

      setState(() {
        _membership = _membership.copyWith(status: newStatus);
      });

      widget.onUpdate();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateClasses(int delta) async {
    final newCount = (_membership.classesRemaining ?? 0) + delta;
    if (newCount < 0) return;

    try {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('memberships')
          .doc(_membership.id)
          .update({'classesRemaining': newCount});

      setState(() {
        _membership = _membership.copyWith(classesRemaining: newCount);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
