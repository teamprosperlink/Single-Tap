import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/category_profile_config.dart';

/// Class model for fitness/education classes
class ClassItem {
  final String id;
  final String name;
  final String? description;
  final String? instructor;
  final String? instructorImage;
  final String? duration; // e.g., "60 mins"
  final List<String> schedule; // e.g., ["Mon 6:00 AM", "Wed 6:00 AM"]
  final String? difficulty; // Beginner, Intermediate, Advanced
  final int? maxParticipants;
  final int? currentParticipants;
  final double? price; // per class
  final String? imageUrl;
  final List<String> tags; // e.g., ["Cardio", "Strength"]

  ClassItem({
    required this.id,
    required this.name,
    this.description,
    this.instructor,
    this.instructorImage,
    this.duration,
    this.schedule = const [],
    this.difficulty,
    this.maxParticipants,
    this.currentParticipants,
    this.price,
    this.imageUrl,
    this.tags = const [],
  });

  factory ClassItem.fromMap(Map<String, dynamic> map, String id) {
    return ClassItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      instructor: map['instructor'],
      instructorImage: map['instructorImage'],
      duration: map['duration'],
      schedule: List<String>.from(map['schedule'] ?? []),
      difficulty: map['difficulty'],
      maxParticipants: map['maxParticipants'],
      currentParticipants: map['currentParticipants'],
      price: map['price']?.toDouble(),
      imageUrl: map['imageUrl'],
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  bool get isFull =>
      maxParticipants != null &&
      currentParticipants != null &&
      currentParticipants! >= maxParticipants!;
}

/// Section displaying fitness/yoga classes
class ClassesSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final List<ClassItem>? classes;
  final VoidCallback? onClassTap;
  final VoidCallback? onBook;

  const ClassesSection({
    super.key,
    required this.businessId,
    required this.config,
    this.classes,
    this.onClassTap,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // For demo, using sample classes
    final displayClasses = classes ?? _getSampleClasses();

    if (displayClasses.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDarkMode, displayClasses.length),
        ...displayClasses.map((classItem) => ClassCard(
              classItem: classItem,
              config: config,
              isDarkMode: isDarkMode,
              onTap: onClassTap,
              onBook: onBook,
            )),
      ],
    );
  }

  List<ClassItem> _getSampleClasses() {
    return [
      ClassItem(
        id: '1',
        name: 'Morning Yoga Flow',
        description: 'Start your day with energizing yoga poses',
        instructor: 'Sarah Johnson',
        duration: '60 mins',
        schedule: ['Mon 6:00 AM', 'Wed 6:00 AM', 'Fri 6:00 AM'],
        difficulty: 'Beginner',
        maxParticipants: 20,
        currentParticipants: 15,
        price: 500,
        tags: ['Yoga', 'Flexibility', 'Mindfulness'],
      ),
      ClassItem(
        id: '2',
        name: 'HIIT Cardio Blast',
        description: 'High-intensity interval training for maximum results',
        instructor: 'Mike Chen',
        duration: '45 mins',
        schedule: ['Tue 7:00 PM', 'Thu 7:00 PM'],
        difficulty: 'Advanced',
        maxParticipants: 15,
        currentParticipants: 14,
        price: 600,
        tags: ['Cardio', 'Weight Loss', 'Strength'],
      ),
      ClassItem(
        id: '3',
        name: 'Zumba Dance Fitness',
        description: 'Fun dance workout with Latin music',
        instructor: 'Maria Garcia',
        duration: '50 mins',
        schedule: ['Sat 10:00 AM', 'Sun 10:00 AM'],
        difficulty: 'Intermediate',
        maxParticipants: 25,
        currentParticipants: 18,
        price: 450,
        tags: ['Dance', 'Cardio', 'Fun'],
      ),
    ];
  }

  Widget _buildSectionHeader(bool isDarkMode, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.fitness_center,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Classes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count available',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Text(
              config.emptyStateIcon,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              config.emptyStateMessage,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying a class
class ClassCard extends StatelessWidget {
  final ClassItem classItem;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final VoidCallback? onBook;

  const ClassCard({
    super.key,
    required this.classItem,
    required this.config,
    required this.isDarkMode,
    this.onTap,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2D2D44) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class header with image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildClassImage(),
                ),
                // Difficulty badge
                if (classItem.difficulty != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        classItem.difficulty!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Full badge
                if (classItem.isFull)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FULL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class name
                  Text(
                    classItem.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),

                  if (classItem.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      classItem.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Instructor and duration
                  Row(
                    children: [
                      if (classItem.instructor != null) ...[
                        Icon(
                          Icons.person,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          classItem.instructor!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (classItem.duration != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          classItem.duration!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Schedule
                  if (classItem.schedule.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: classItem.schedule.map((time) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: config.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: config.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Tags
                  if (classItem.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: classItem.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white10 : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDarkMode ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Participants and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (classItem.price != null)
                            Text(
                              '₹${classItem.price!.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: config.primaryColor,
                              ),
                            ),
                          if (classItem.maxParticipants != null)
                            Text(
                              '${classItem.currentParticipants ?? 0}/${classItem.maxParticipants} spots',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: classItem.isFull ? null : onBook,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          classItem.isFull ? 'Full' : 'Book',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassImage() {
    if (classItem.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: classItem.imageUrl!,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildImagePlaceholder(),
        errorWidget: (context, url, error) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 140,
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.fitness_center,
          size: 48,
          color: config.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (classItem.difficulty?.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return config.primaryColor;
    }
  }
}
