import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer loading placeholders for business screens.
///
/// Each widget accepts [isDarkMode] to apply the correct shimmer palette.

// ---------------------------------------------------------------------------
// ShimmerCard — matches catalog card layout (image + 3 text lines)
// ---------------------------------------------------------------------------

class ShimmerCard extends StatelessWidget {
  final bool isDarkMode;

  const ShimmerCard({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      isDarkMode: isDarkMode,
      child: Container(
        decoration: BoxDecoration(
          color: _placeholderColor(isDarkMode),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image placeholder with rounded top corners
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: _placeholderColor(isDarkMode),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
            ),

            // Text line placeholders
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _linePlaceholder(
                    isDarkMode: isDarkMode,
                    widthFraction: 0.8,
                  ),
                  const SizedBox(height: 8),
                  _linePlaceholder(
                    isDarkMode: isDarkMode,
                    widthFraction: 0.5,
                  ),
                  const SizedBox(height: 8),
                  _linePlaceholder(
                    isDarkMode: isDarkMode,
                    widthFraction: 0.3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerListItem — matches booking / review list item
// ---------------------------------------------------------------------------

class ShimmerListItem extends StatelessWidget {
  final bool isDarkMode;

  const ShimmerListItem({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      isDarkMode: isDarkMode,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _placeholderColor(isDarkMode),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Text lines
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _placeholderColor(isDarkMode),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _placeholderColor(isDarkMode),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerDashboard — matches business hub dashboard layout
// ---------------------------------------------------------------------------

class ShimmerDashboard extends StatelessWidget {
  final bool isDarkMode;

  const ShimmerDashboard({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      isDarkMode: isDarkMode,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick-action row (4 icons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (_) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _placeholderColor(isDarkMode),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _placeholderColor(isDarkMode),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 24),

            // 2x2 grid of shimmer cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: List.generate(4, (_) {
                return ShimmerCard(isDarkMode: isDarkMode);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerProfileHeader — matches public business profile header
// ---------------------------------------------------------------------------

class ShimmerProfileHeader extends StatelessWidget {
  final bool isDarkMode;

  const ShimmerProfileHeader({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      isDarkMode: isDarkMode,
      child: Column(
        children: [
          // Cover image placeholder
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: _placeholderColor(isDarkMode),
            ),
          ),

          const SizedBox(height: 16),

          // Action button circles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _placeholderColor(isDarkMode),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in [Shimmer.fromColors] with the correct palette for the
/// current theme mode.
Widget _shimmerWrap({required bool isDarkMode, required Widget child}) {
  return Shimmer.fromColors(
    baseColor: isDarkMode ? const Color(0xFF2A2A2E) : Colors.grey[300]!,
    highlightColor: isDarkMode ? const Color(0xFF3A3A3E) : Colors.grey[100]!,
    child: child,
  );
}

/// Returns the solid placeholder colour used inside shimmer containers.
Color _placeholderColor(bool isDarkMode) {
  return isDarkMode ? const Color(0xFF2A2A2E) : Colors.grey[300]!;
}

/// Builds a single text-line placeholder whose width is a fraction of the
/// available horizontal space.
Widget _linePlaceholder({
  required bool isDarkMode,
  required double widthFraction,
}) {
  return FractionallySizedBox(
    widthFactor: widthFraction,
    child: Container(
      height: 12,
      decoration: BoxDecoration(
        color: _placeholderColor(isDarkMode),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}
