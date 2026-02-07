import 'package:flutter/material.dart';
import '../../models/business_model.dart';
import '../../screens/business/profile_view/business_profile_screen.dart';
import 'business_card.dart';

/// A wrapper around BusinessCard that navigates to the BusinessProfileScreen
/// when tapped.
///
/// This widget is designed for customer-facing business listings where
/// tapping should open the detailed profile view.
///
/// Usage:
/// ```dart
/// BusinessProfileCard(
///   business: businessModel,
///   isCompact: true,
/// )
/// ```
class BusinessProfileCard extends StatelessWidget {
  final BusinessModel business;
  final bool isCompact;
  final bool showRating;
  final bool showStatus;

  const BusinessProfileCard({
    super.key,
    required this.business,
    this.isCompact = false,
    this.showRating = true,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return BusinessCard(
      business: business,
      isCompact: isCompact,
      showRating: showRating,
      showStatus: showStatus,
      onTap: () => _navigateToProfile(context),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(businessId: business.id),
      ),
    );
  }
}

/// Extension methods for easy navigation to business profile
extension BusinessProfileNavigation on BuildContext {
  /// Navigate to a business profile screen
  void navigateToBusinessProfile(String businessId) {
    Navigator.push(
      this,
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(businessId: businessId),
      ),
    );
  }

  /// Navigate to a business profile screen with custom transition
  void navigateToBusinessProfileWithTransition(
    String businessId, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    Navigator.push(
      this,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BusinessProfileScreen(
          businessId: businessId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: duration,
      ),
    );
  }
}
