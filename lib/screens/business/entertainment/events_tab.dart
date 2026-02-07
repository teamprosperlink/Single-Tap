import '../../../services/firebase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../models/business_model.dart';

/// Event categories (aligned with BookMyShow, Paytm Insider, Eventbrite)
class EventCategories {
  static const List<String> all = [
    'Live Music / Concert',
    'Stand-Up Comedy',
    'DJ Night / Club Night',
    'Theatre / Drama',
    'Dance Performance',
    'Film Screening',
    'Gaming Tournament',
    'Corporate Event',
    'Wedding / Reception',
    'Birthday Party',
    'Kids Entertainment',
    'Workshop / Masterclass',
    'Cultural Program',
    'Sports Event',
    'Award Ceremony',
    'Open Mic',
    'Karaoke Night',
    'Other',
  ];

  static IconData getIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('music') || lower.contains('concert')) return Icons.music_note;
    if (lower.contains('comedy') || lower.contains('stand-up')) return Icons.emoji_emotions;
    if (lower.contains('dj') || lower.contains('club')) return Icons.nightlife;
    if (lower.contains('theatre') || lower.contains('drama')) return Icons.theater_comedy;
    if (lower.contains('dance')) return Icons.directions_run;
    if (lower.contains('film') || lower.contains('screening')) return Icons.movie;
    if (lower.contains('gaming') || lower.contains('tournament')) return Icons.sports_esports;
    if (lower.contains('corporate')) return Icons.business;
    if (lower.contains('wedding') || lower.contains('reception')) return Icons.celebration;
    if (lower.contains('birthday')) return Icons.cake;
    if (lower.contains('kids')) return Icons.child_care;
    if (lower.contains('workshop') || lower.contains('masterclass')) return Icons.school;
    if (lower.contains('cultural')) return Icons.palette;
    if (lower.contains('sports')) return Icons.sports;
    if (lower.contains('award')) return Icons.emoji_events;
    if (lower.contains('open mic')) return Icons.mic;
    if (lower.contains('karaoke')) return Icons.mic_external_on;
    return Icons.event;
  }

  static Color getColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('music') || lower.contains('concert')) return const Color(0xFFE91E63);
    if (lower.contains('comedy') || lower.contains('stand-up')) return const Color(0xFFFF9800);
    if (lower.contains('dj') || lower.contains('club')) return const Color(0xFF9C27B0);
    if (lower.contains('theatre') || lower.contains('drama')) return const Color(0xFF795548);
    if (lower.contains('dance')) return const Color(0xFFE91E63);
    if (lower.contains('film') || lower.contains('screening')) return const Color(0xFF37474F);
    if (lower.contains('gaming') || lower.contains('tournament')) return const Color(0xFF4CAF50);
    if (lower.contains('corporate')) return const Color(0xFF1565C0);
    if (lower.contains('wedding') || lower.contains('reception')) return const Color(0xFFD81B60);
    if (lower.contains('birthday')) return const Color(0xFFFF5722);
    if (lower.contains('kids')) return const Color(0xFF00BCD4);
    if (lower.contains('workshop') || lower.contains('masterclass')) return const Color(0xFF3F51B5);
    if (lower.contains('cultural')) return const Color(0xFF9C27B0);
    if (lower.contains('sports')) return const Color(0xFF2E7D32);
    if (lower.contains('award')) return const Color(0xFFFFC107);
    if (lower.contains('open mic')) return const Color(0xFF00897B);
    if (lower.contains('karaoke')) return const Color(0xFFAB47BC);
    return const Color(0xFF78909C);
  }
}

/// Event status
enum EventStatus { upcoming, ongoing, completed, cancelled }

/// Event model for entertainment businesses
class EventModel {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String status;
  final DateTime? eventDate;
  final String? startTime;
  final String? endTime;
  final String? venue;
  final double? ticketPrice;
  final double? vipPrice;
  final int? totalSeats;
  final int? bookedSeats;
  final String? ageRestriction;
  final String? dressCode;
  final List<String>? performers;
  final List<String>? highlights;
  final bool isFeatured;
  final bool isRecurring;
  final String? recurringSchedule;
  final String? imageUrl;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.status = 'upcoming',
    this.eventDate,
    this.startTime,
    this.endTime,
    this.venue,
    this.ticketPrice,
    this.vipPrice,
    this.totalSeats,
    this.bookedSeats,
    this.ageRestriction,
    this.dressCode,
    this.performers,
    this.highlights,
    this.isFeatured = false,
    this.isRecurring = false,
    this.recurringSchedule,
    this.imageUrl,
    required this.createdAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      category: data['category'] ?? 'Other',
      status: data['status'] ?? 'upcoming',
      eventDate: (data['eventDate'] as Timestamp?)?.toDate(),
      startTime: data['startTime'],
      endTime: data['endTime'],
      venue: data['venue'],
      ticketPrice: (data['ticketPrice'] as num?)?.toDouble(),
      vipPrice: (data['vipPrice'] as num?)?.toDouble(),
      totalSeats: data['totalSeats'] as int?,
      bookedSeats: data['bookedSeats'] as int?,
      ageRestriction: data['ageRestriction'],
      dressCode: data['dressCode'],
      performers: data['performers'] != null
          ? List<String>.from(data['performers'])
          : null,
      highlights: data['highlights'] != null
          ? List<String>.from(data['highlights'])
          : null,
      isFeatured: data['isFeatured'] == true,
      isRecurring: data['isRecurring'] == true,
      recurringSchedule: data['recurringSchedule'],
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate!) : null,
      'startTime': startTime,
      'endTime': endTime,
      'venue': venue,
      'ticketPrice': ticketPrice,
      'vipPrice': vipPrice,
      'totalSeats': totalSeats,
      'bookedSeats': bookedSeats ?? 0,
      'ageRestriction': ageRestriction,
      'dressCode': dressCode,
      'performers': performers,
      'highlights': highlights,
      'isFeatured': isFeatured,
      'isRecurring': isRecurring,
      'recurringSchedule': recurringSchedule,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Events tab for entertainment businesses — CRUD for events/experiences
class EventsTab extends StatefulWidget {
  final BusinessModel business;

  const EventsTab({super.key, required this.business});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Upcoming',
    'Ongoing',
    'Completed',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    backgroundColor:
                        isDark ? const Color(0xFF2D2D44) : Colors.grey[100],
                    selectedColor:
                        const Color(0xFFF97316).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFFF97316)
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    checkmarkColor: const Color(0xFFF97316),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFF97316)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Events list
        Expanded(
          child: _buildEventsList(isDark),
        ),
      ],
    );
  }

  Widget _buildEventsList(bool isDark) {
    Query query = FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('events')
        .orderBy('eventDate', descending: false)
        .limit(50);

    if (_selectedFilter != 'All') {
      query = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('events')
          .where('status', isEqualTo: _selectedFilter.toLowerCase())
          .orderBy('eventDate', descending: false)
          .limit(50);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDark);
        }

        final events = snapshot.data!.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: events.length,
          itemBuilder: (context, index) {
            return _EventCard(
              event: events[index],
              isDark: isDark,
              onEdit: () => _showEventForm(event: events[index]),
              onDelete: () => _deleteEvent(events[index]),
              onToggleStatus: () => _toggleEventStatus(events[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add events, shows, or experiences',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showEventForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventForm({EventModel? event}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(
        businessId: widget.business.id,
        event: event,
      ),
    );
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.business.id)
          .collection('events')
          .doc(event.id)
          .delete();
    }
  }

  Future<void> _toggleEventStatus(EventModel event) async {
    final statuses = ['upcoming', 'ongoing', 'completed', 'cancelled'];
    final currentIndex = statuses.indexOf(event.status);
    final nextStatus = statuses[(currentIndex + 1) % statuses.length];

    await FirebaseProvider.firestore
        .collection('businesses')
        .doc(widget.business.id)
        .collection('events')
        .doc(event.id)
        .update({'status': nextStatus});
  }
}

/// Event card widget
class _EventCard extends StatelessWidget {
  final EventModel event;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _EventCard({
    required this.event,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = EventCategories.getColor(event.category);
    final catIcon = EventCategories.getIcon(event.category);
    final statusColor = _getStatusColor(event.status);
    final dateStr = event.eventDate != null
        ? DateFormat('EEE, dd MMM yyyy').format(event.eventDate!)
        : 'Date TBD';
    final timeStr = [event.startTime, event.endTime]
        .where((t) => t != null && t.isNotEmpty)
        .join(' - ');
    final seatsLeft = (event.totalSeats ?? 0) - (event.bookedSeats ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor, catColor.withValues(alpha: 0.7)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(catIcon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.isFeatured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text('Featured',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.grey[800],
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.access_time,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),

                if (event.venue != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.place,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        event.venue!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],

                // Price and seats
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (event.ticketPrice != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${_formatPrice(event.ticketPrice!)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ),
                    ],
                    if (event.vipPrice != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'VIP ₹${_formatPrice(event.vipPrice!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        event.status[0].toUpperCase() +
                            event.status.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Seats info
                if (event.totalSeats != null && event.totalSeats! > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.event_seat,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '${event.bookedSeats ?? 0}/${event.totalSeats} booked',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                      if (seatsLeft > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$seatsLeft seats left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: seatsLeft < 20
                                ? Colors.red
                                : const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: event.totalSeats! > 0
                          ? (event.bookedSeats ?? 0) / event.totalSeats!
                          : 0,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        seatsLeft < 20 ? Colors.red : const Color(0xFFF97316),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],

                // Performers
                if (event.performers != null &&
                    event.performers!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: event.performers!.map((performer) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person,
                                size: 12,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              performer,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Age restriction and dress code
                if (event.ageRestriction != null ||
                    event.dressCode != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (event.ageRestriction != null) ...[
                        Icon(Icons.person_outline,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          event.ageRestriction!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                      if (event.ageRestriction != null &&
                          event.dressCode != null)
                        const SizedBox(width: 16),
                      if (event.dressCode != null) ...[
                        Icon(Icons.checkroom,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          event.dressCode!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white70 : Colors.grey[700],
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleStatus,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Status'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: BorderSide(
                        color: const Color(0xFFF97316)
                            .withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return const Color(0xFF2196F3);
      case 'ongoing':
        return const Color(0xFF4CAF50);
      case 'completed':
        return const Color(0xFF78909C);
      case 'cancelled':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF78909C);
    }
  }

  String _formatPrice(double price) {
    if (price >= 10000000) return '${(price / 10000000).toStringAsFixed(1)} Cr';
    if (price >= 100000) return '${(price / 100000).toStringAsFixed(1)} L';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(1)}K';
    return price.toStringAsFixed(0);
  }
}

/// Event form bottom sheet
class _EventFormSheet extends StatefulWidget {
  final String businessId;
  final EventModel? event;

  const _EventFormSheet({required this.businessId, this.event});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _venueController;
  late TextEditingController _ticketPriceController;
  late TextEditingController _vipPriceController;
  late TextEditingController _totalSeatsController;
  late TextEditingController _performersController;
  late TextEditingController _highlightsController;

  String _category = EventCategories.all.first;
  DateTime? _eventDate;
  String? _startTime;
  String? _endTime;
  String? _ageRestriction;
  String? _dressCode;
  bool _isFeatured = false;
  bool _isRecurring = false;
  String? _recurringSchedule;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController =
        TextEditingController(text: e?.description ?? '');
    _venueController = TextEditingController(text: e?.venue ?? '');
    _ticketPriceController = TextEditingController(
        text: e?.ticketPrice != null ? e!.ticketPrice!.toStringAsFixed(0) : '');
    _vipPriceController = TextEditingController(
        text: e?.vipPrice != null ? e!.vipPrice!.toStringAsFixed(0) : '');
    _totalSeatsController = TextEditingController(
        text: e?.totalSeats != null ? e!.totalSeats!.toString() : '');
    _performersController = TextEditingController(
        text: e?.performers?.join(', ') ?? '');
    _highlightsController = TextEditingController(
        text: e?.highlights?.join(', ') ?? '');

    if (e != null) {
      _category = e.category;
      _eventDate = e.eventDate;
      _startTime = e.startTime;
      _endTime = e.endTime;
      _ageRestriction = e.ageRestriction;
      _dressCode = e.dressCode;
      _isFeatured = e.isFeatured;
      _isRecurring = e.isRecurring;
      _recurringSchedule = e.recurringSchedule;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _ticketPriceController.dispose();
    _vipPriceController.dispose();
    _totalSeatsController.dispose();
    _performersController.dispose();
    _highlightsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.event != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  isEditing ? 'Edit Event' : 'Add Event',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Event Title *', isDark),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Category
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: _inputDecoration('Category', isDark),
                      items: EventCategories.all
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Icon(EventCategories.getIcon(c),
                                        size: 18,
                                        color: EventCategories.getColor(c)),
                                    const SizedBox(width: 8),
                                    Text(c),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _inputDecoration('Description', isDark),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Event date
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _eventDate ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (date != null) setState(() => _eventDate = date);
                      },
                      child: InputDecorator(
                        decoration: _inputDecoration('Event Date', isDark),
                        child: Text(
                          _eventDate != null
                              ? DateFormat('dd MMM yyyy').format(_eventDate!)
                              : 'Select date',
                          style: TextStyle(
                            color: _eventDate != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Time row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(true),
                            child: InputDecorator(
                              decoration:
                                  _inputDecoration('Start Time', isDark),
                              child: Text(
                                _startTime ?? 'Select',
                                style: TextStyle(
                                  color: _startTime != null
                                      ? (isDark
                                          ? Colors.white
                                          : Colors.black87)
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(false),
                            child: InputDecorator(
                              decoration:
                                  _inputDecoration('End Time', isDark),
                              child: Text(
                                _endTime ?? 'Select',
                                style: TextStyle(
                                  color: _endTime != null
                                      ? (isDark
                                          ? Colors.white
                                          : Colors.black87)
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Venue
                    TextFormField(
                      controller: _venueController,
                      decoration: _inputDecoration('Venue / Location', isDark),
                    ),
                    const SizedBox(height: 14),

                    // Price row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ticketPriceController,
                            decoration:
                                _inputDecoration('Ticket Price (₹)', isDark),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _vipPriceController,
                            decoration:
                                _inputDecoration('VIP Price (₹)', isDark),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total seats
                    TextFormField(
                      controller: _totalSeatsController,
                      decoration: _inputDecoration('Total Seats', isDark),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Age restriction
                    DropdownButtonFormField<String>(
                      initialValue: _ageRestriction,
                      decoration:
                          _inputDecoration('Age Restriction', isDark),
                      items: [
                        'All Ages',
                        '5+',
                        '12+',
                        '16+',
                        '18+',
                        '21+',
                      ]
                          .map((a) =>
                              DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _ageRestriction = v),
                    ),
                    const SizedBox(height: 14),

                    // Dress code
                    DropdownButtonFormField<String>(
                      initialValue: _dressCode,
                      decoration: _inputDecoration('Dress Code', isDark),
                      items: [
                        'Casual',
                        'Smart Casual',
                        'Formal',
                        'Traditional',
                        'Theme-Based',
                        'No Restriction',
                      ]
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _dressCode = v),
                    ),
                    const SizedBox(height: 14),

                    // Performers
                    TextFormField(
                      controller: _performersController,
                      decoration: _inputDecoration(
                          'Performers (comma-separated)', isDark),
                    ),
                    const SizedBox(height: 14),

                    // Highlights
                    TextFormField(
                      controller: _highlightsController,
                      decoration: _inputDecoration(
                          'Highlights (comma-separated)', isDark),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    // Featured toggle
                    SwitchListTile(
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      title: Text(
                        'Featured Event',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      activeTrackColor: const Color(0xFFF97316),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Recurring toggle
                    SwitchListTile(
                      value: _isRecurring,
                      onChanged: (v) => setState(() => _isRecurring = v),
                      title: Text(
                        'Recurring Event',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      activeTrackColor: const Color(0xFFF97316),
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (_isRecurring) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _recurringSchedule,
                        decoration:
                            _inputDecoration('Recurring Schedule', isDark),
                        items: [
                          'Daily',
                          'Weekly',
                          'Bi-Weekly',
                          'Monthly',
                          'Every Weekend',
                          'Every Friday',
                          'Every Saturday',
                        ]
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _recurringSchedule = v),
                      ),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Event' : 'Add Event',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get isEditing => widget.event != null;

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white54 : Colors.grey[600],
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2D2D44) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF97316)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && mounted) {
      final formatted = time.format(context);
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final performers = _performersController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final highlights = _highlightsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final eventData = EventModel(
        id: widget.event?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        category: _category,
        status: widget.event?.status ?? 'upcoming',
        eventDate: _eventDate,
        startTime: _startTime,
        endTime: _endTime,
        venue: _venueController.text.trim().isNotEmpty
            ? _venueController.text.trim()
            : null,
        ticketPrice: double.tryParse(_ticketPriceController.text),
        vipPrice: double.tryParse(_vipPriceController.text),
        totalSeats: int.tryParse(_totalSeatsController.text),
        bookedSeats: widget.event?.bookedSeats ?? 0,
        ageRestriction: _ageRestriction,
        dressCode: _dressCode,
        performers: performers.isNotEmpty ? performers : null,
        highlights: highlights.isNotEmpty ? highlights : null,
        isFeatured: _isFeatured,
        isRecurring: _isRecurring,
        recurringSchedule: _isRecurring ? _recurringSchedule : null,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
      );

      final collection = FirebaseProvider.firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('events');

      if (isEditing) {
        await collection.doc(widget.event!.id).update(eventData.toFirestore());
      } else {
        await collection.add(eventData.toFirestore());
      }

      if (mounted) Navigator.pop(context);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
