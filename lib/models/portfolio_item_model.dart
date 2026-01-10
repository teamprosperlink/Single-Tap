import 'package:cloud_firestore/cloud_firestore.dart';

/// Portfolio item model for professional accounts
class PortfolioItemModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> images;
  final String? projectUrl;
  final List<String> tags;
  final String? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int order;
  final bool isVisible;

  PortfolioItemModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.images = const [],
    this.projectUrl,
    this.tags = const [],
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.order = 0,
    this.isVisible = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from Firestore document
  factory PortfolioItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioItemModel.fromMap(data, doc.id);
  }

  /// Create from map with ID
  factory PortfolioItemModel.fromMap(Map<String, dynamic> map, String id) {
    return PortfolioItemModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      images: List<String>.from(map['images'] ?? []),
      projectUrl: map['projectUrl'],
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      order: map['order'] ?? 0,
      isVisible: map['isVisible'] ?? true,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'images': images,
      'projectUrl': projectUrl,
      'tags': tags,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'order': order,
      'isVisible': isVisible,
    };
  }

  /// Get the primary/cover image
  String? get coverImage => images.isNotEmpty ? images.first : null;

  /// Check if has external link
  bool get hasProjectUrl => projectUrl != null && projectUrl!.isNotEmpty;

  /// Create a copy with updated fields
  PortfolioItemModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    List<String>? images,
    String? projectUrl,
    List<String>? tags,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
    bool? isVisible,
  }) {
    return PortfolioItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      projectUrl: projectUrl ?? this.projectUrl,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// Professional categories for dropdown
class ProfessionalCategories {
  static const List<String> all = [
    'Freelancer',
    'Consultant',
    'Agency',
    'Coach / Mentor',
    'Tutor / Instructor',
    'Creative Professional',
    'Technical Expert',
    'Service Provider',
    'Contractor',
    'Healthcare Professional',
    'Legal Professional',
    'Financial Advisor',
    'Other',
  ];
}

/// Specializations by category
class Specializations {
  static const Map<String, List<String>> byCategory = {
    'Design & Creative': [
      'Logo Design',
      'UI/UX Design',
      'Graphic Design',
      'Brand Identity',
      'Illustration',
      'Packaging Design',
      'Print Design',
      'Motion Graphics',
      'Web Design',
      '3D Design',
    ],
    'Web Development': [
      'Frontend Development',
      'Backend Development',
      'Full Stack',
      'WordPress',
      'Shopify',
      'React',
      'Angular',
      'Vue.js',
      'Node.js',
      'Python/Django',
      'PHP/Laravel',
      'E-commerce',
    ],
    'Mobile Development': [
      'iOS Development',
      'Android Development',
      'Flutter',
      'React Native',
      'Cross-platform',
      'App Design',
    ],
    'Writing & Content': [
      'Copywriting',
      'Blog Writing',
      'Technical Writing',
      'SEO Content',
      'Ghostwriting',
      'Editing & Proofreading',
      'Translation',
      'Script Writing',
      'Resume Writing',
    ],
    'Marketing & SEO': [
      'Social Media Marketing',
      'SEO',
      'PPC / Google Ads',
      'Email Marketing',
      'Content Marketing',
      'Influencer Marketing',
      'Brand Strategy',
      'Market Research',
      'Lead Generation',
    ],
    'Video & Animation': [
      'Video Editing',
      '2D Animation',
      '3D Animation',
      'Motion Graphics',
      'Explainer Videos',
      'YouTube Videos',
      'Product Videos',
      'Drone Videography',
    ],
    'Music & Audio': [
      'Music Production',
      'Mixing & Mastering',
      'Voice Over',
      'Podcast Editing',
      'Sound Design',
      'Jingles',
      'Audio Editing',
    ],
    'Business & Finance': [
      'Business Planning',
      'Financial Analysis',
      'Accounting',
      'Tax Consulting',
      'Investment Advice',
      'Bookkeeping',
      'Business Consulting',
    ],
    'Education & Tutoring': [
      'Academic Tutoring',
      'Language Teaching',
      'Test Prep',
      'Online Courses',
      'Music Lessons',
      'Art Lessons',
      'Coding Lessons',
    ],
    'Photography': [
      'Portrait Photography',
      'Product Photography',
      'Event Photography',
      'Real Estate Photography',
      'Food Photography',
      'Photo Editing',
      'Photo Retouching',
    ],
  };

  static List<String> getForCategory(String? category) {
    if (category == null) return [];
    return byCategory[category] ?? [];
  }

  /// Get all unique specializations
  static List<String> get all {
    final Set<String> uniqueSpecs = {};
    for (final specs in byCategory.values) {
      uniqueSpecs.addAll(specs);
    }
    return uniqueSpecs.toList()..sort();
  }

  /// Popular/common specializations for quick selection
  static const List<String> popular = [
    'Web Development',
    'Mobile Development',
    'UI/UX Design',
    'Graphic Design',
    'Content Writing',
    'Digital Marketing',
    'Video Editing',
    'Photography',
    'Social Media',
    'SEO',
    'Data Analysis',
    'Consulting',
  ];
}
