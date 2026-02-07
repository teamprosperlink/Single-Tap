import 'package:flutter/material.dart';
import '../../../../models/business_model.dart';
import '../../../../config/category_profile_config.dart';
import '../sections/hero_section.dart';
import '../sections/quick_actions_bar.dart';
import '../sections/highlights_section.dart';
import '../sections/services_section.dart';
import '../sections/gallery_section.dart';
import '../sections/reviews_section.dart';
import '../sections/hours_section.dart';
import '../sections/location_section.dart';

/// Generic template for businesses without specific templates
/// Serves as the fallback and base template
class GenericTemplate extends StatelessWidget {
  final BusinessModel business;
  final CategoryProfileConfig config;

  const GenericTemplate({
    super.key,
    required this.business,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Hero section with cover image and business info
          HeroSection(
            business: business,
            config: config,
          ),

          // Quick action buttons
          SliverToBoxAdapter(
            child: QuickActionsBar(
              business: business,
              config: config,
            ),
          ),

          // Highlights / Tags
          SliverToBoxAdapter(
            child: HighlightsSection(
              business: business,
              config: config,
            ),
          ),

          // About section
          SliverToBoxAdapter(
            child: AboutSection(
              business: business,
              config: config,
            ),
          ),

          // Services section
          SliverToBoxAdapter(
            child: ServicesSection(
              businessId: business.id,
              business: business,
              config: config,
            ),
          ),

          // Gallery
          SliverToBoxAdapter(
            child: GallerySection(
              business: business,
              config: config,
            ),
          ),

          // Reviews
          SliverToBoxAdapter(
            child: ReviewsSection(
              businessId: business.id,
              config: config,
            ),
          ),

          // Hours
          SliverToBoxAdapter(
            child: HoursSection(
              business: business,
              config: config,
            ),
          ),

          // Location
          SliverToBoxAdapter(
            child: LocationSection(
              business: business,
              config: config,
            ),
          ),

          // Contact
          SliverToBoxAdapter(
            child: ContactSection(
              business: business,
              config: config,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}
