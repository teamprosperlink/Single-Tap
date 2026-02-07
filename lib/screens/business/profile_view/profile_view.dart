// Business Profile View exports
//
// This barrel file exports all profile view related components
// for easy importing in other parts of the app.
//
// Usage:
// ```dart
// import 'package:supper/screens/business/profile_view/profile_view.dart';
//
// // Navigate to profile
// Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (_) => BusinessProfileScreen(businessId: 'abc123'),
//   ),
// );
// ```

// Main screen
export 'business_profile_screen.dart';

// Templates (MVP: using generic template for all categories)
export 'templates/generic_template.dart';
// Note: Category-specific templates archived for future enhancement

// Sections
export 'sections/hero_section.dart';
export 'sections/quick_actions_bar.dart';
export 'sections/highlights_section.dart';
export 'sections/menu_section.dart';
export 'sections/services_section.dart';
export 'sections/rooms_section.dart';
export 'sections/gallery_section.dart';
export 'sections/reviews_section.dart';
export 'sections/hours_section.dart';
export 'sections/location_section.dart';
export 'sections/products_section.dart';
export 'sections/properties_section.dart';
export 'sections/classes_section.dart';
export 'sections/memberships_section.dart';
export 'sections/courses_section.dart';
