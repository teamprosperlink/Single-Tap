import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../config/category_profile_config.dart';

/// Course model for education businesses
class CourseItem {
  final String id;
  final String name;
  final String? description;
  final String? instructor;
  final String? instructorImage;
  final String? duration; // e.g., "3 months", "40 hours"
  final String? level; // Beginner, Intermediate, Advanced
  final String? mode; // Online, Offline, Hybrid
  final double? price;
  final double? originalPrice;
  final String? imageUrl;
  final double? rating;
  final int? enrolledCount;
  final List<String> syllabus;
  final List<String> tags;
  final String? startDate;
  final bool isPopular;

  CourseItem({
    required this.id,
    required this.name,
    this.description,
    this.instructor,
    this.instructorImage,
    this.duration,
    this.level,
    this.mode,
    this.price,
    this.originalPrice,
    this.imageUrl,
    this.rating,
    this.enrolledCount,
    this.syllabus = const [],
    this.tags = const [],
    this.startDate,
    this.isPopular = false,
  });

  factory CourseItem.fromMap(Map<String, dynamic> map, String id) {
    return CourseItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      instructor: map['instructor'],
      instructorImage: map['instructorImage'],
      duration: map['duration'],
      level: map['level'],
      mode: map['mode'],
      price: map['price']?.toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      imageUrl: map['imageUrl'],
      rating: map['rating']?.toDouble(),
      enrolledCount: map['enrolledCount'],
      syllabus: List<String>.from(map['syllabus'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      startDate: map['startDate'],
      isPopular: map['isPopular'] ?? false,
    );
  }

  bool get hasDiscount =>
      originalPrice != null && price != null && originalPrice! > price!;

  int get discountPercent {
    if (!hasDiscount) return 0;
    return (((originalPrice! - price!) / originalPrice!) * 100).round();
  }
}

/// Section displaying courses for education businesses
class CoursesSection extends StatelessWidget {
  final String businessId;
  final CategoryProfileConfig config;
  final List<CourseItem>? courses;
  final VoidCallback? onCourseTap;
  final VoidCallback? onEnroll;

  const CoursesSection({
    super.key,
    required this.businessId,
    required this.config,
    this.courses,
    this.onCourseTap,
    this.onEnroll,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // For demo, using sample courses
    final displayCourses = courses ?? _getSampleCourses();

    if (displayCourses.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isDarkMode, displayCourses.length),
        ...displayCourses.map((course) => CourseCard(
              course: course,
              config: config,
              isDarkMode: isDarkMode,
              onTap: onCourseTap,
              onEnroll: onEnroll,
            )),
      ],
    );
  }

  List<CourseItem> _getSampleCourses() {
    return [
      CourseItem(
        id: '1',
        name: 'Full Stack Web Development',
        description:
            'Learn to build complete web applications from scratch using modern technologies',
        instructor: 'John Smith',
        duration: '6 months',
        level: 'Beginner',
        mode: 'Hybrid',
        price: 49999,
        originalPrice: 79999,
        rating: 4.8,
        enrolledCount: 1250,
        syllabus: [
          'HTML, CSS & JavaScript',
          'React & Node.js',
          'Database Management',
          'Cloud Deployment',
        ],
        tags: ['Web Development', 'JavaScript', 'React'],
        startDate: 'Jan 15, 2024',
        isPopular: true,
      ),
      CourseItem(
        id: '2',
        name: 'Data Science with Python',
        description:
            'Master data analysis, visualization, and machine learning with Python',
        instructor: 'Dr. Priya Sharma',
        duration: '4 months',
        level: 'Intermediate',
        mode: 'Online',
        price: 39999,
        rating: 4.6,
        enrolledCount: 890,
        syllabus: [
          'Python Fundamentals',
          'Data Analysis with Pandas',
          'Machine Learning Basics',
          'Real-world Projects',
        ],
        tags: ['Data Science', 'Python', 'ML'],
      ),
      CourseItem(
        id: '3',
        name: 'Digital Marketing Masterclass',
        description: 'Complete guide to modern digital marketing strategies',
        instructor: 'Rahul Kapoor',
        duration: '3 months',
        level: 'Beginner',
        mode: 'Offline',
        price: 24999,
        originalPrice: 34999,
        rating: 4.5,
        enrolledCount: 650,
        tags: ['Marketing', 'SEO', 'Social Media'],
      ),
    ];
  }

  Widget _buildSectionHeader(bool isDarkMode, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.school,
            size: 20,
            color: config.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Courses',
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

/// Card widget for displaying a course
class CourseCard extends StatelessWidget {
  final CourseItem course;
  final CategoryProfileConfig config;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final VoidCallback? onEnroll;

  const CourseCard({
    super.key,
    required this.course,
    required this.config,
    required this.isDarkMode,
    this.onTap,
    this.onEnroll,
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
            // Course image header
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildCourseImage(),
                ),
                // Popular badge
                if (course.isPopular)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Popular',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Discount badge
                if (course.hasDiscount)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${course.discountPercent}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Mode badge
                if (course.mode != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getModeColor(),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getModeIcon(),
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.mode!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                  // Course name
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (course.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      course.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Course info row
                  Row(
                    children: [
                      if (course.instructor != null) ...[
                        Icon(
                          Icons.person,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            course.instructor!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (course.duration != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.duration!,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Level and rating
                  Row(
                    children: [
                      if (course.level != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.level!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getLevelColor(),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (course.rating != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                      if (course.enrolledCount != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.people,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${course.enrolledCount} enrolled',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Tags
                  if (course.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: course.tags.take(3).map((tag) {
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

                  // Price and enroll button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (course.price != null)
                            Text(
                              '₹${_formatPrice(course.price!)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: config.primaryColor,
                              ),
                            ),
                          if (course.hasDiscount)
                            Text(
                              '₹${_formatPrice(course.originalPrice!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    isDarkMode ? Colors.white38 : Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: onEnroll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Enroll Now',
                          style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildCourseImage() {
    if (course.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: course.imageUrl!,
        height: 160,
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
      height: 160,
      color: config.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.school,
          size: 48,
          color: config.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getModeColor() {
    switch (course.mode?.toLowerCase()) {
      case 'online':
        return Colors.blue;
      case 'offline':
        return Colors.green;
      case 'hybrid':
        return Colors.purple;
      default:
        return config.primaryColor;
    }
  }

  IconData _getModeIcon() {
    switch (course.mode?.toLowerCase()) {
      case 'online':
        return Icons.laptop;
      case 'offline':
        return Icons.location_on;
      case 'hybrid':
        return Icons.swap_horiz;
      default:
        return Icons.school;
    }
  }

  Color _getLevelColor() {
    switch (course.level?.toLowerCase()) {
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

  String _formatPrice(double price) {
    if (price >= 100000) {
      return '${(price / 100000).toStringAsFixed(1)}L';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}
