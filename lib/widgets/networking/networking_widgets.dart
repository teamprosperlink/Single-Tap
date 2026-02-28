import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'networking_constants.dart';

/// Shared reusable UI widgets for all networking screens.
class NetworkingWidgets {
  NetworkingWidgets._();

  // ── Standard dark gradient AppBar ──
  static AppBar networkingAppBar({
    required String title,
    VoidCallback? onBack,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leadingWidth: onBack != null ? 46 : null,
      leading: onBack != null
          ? IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            )
          : null,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(40, 40, 40, 1),
              Color.fromRGBO(64, 64, 64, 1),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: Colors.white, width: 0.5),
          ),
        ),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: actions ?? const [],
    );
  }

  // ── Standard body gradient (dark) ──
  static BoxDecoration bodyGradient({bool fourStop = false}) {
    if (fourStop) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(64, 64, 64, 1),
            Color.fromRGBO(64, 64, 64, 1),
            Color.fromRGBO(40, 40, 40, 1),
            Color.fromRGBO(0, 0, 0, 1),
          ],
          stops: [0.0, 0.45, 0.7, 1.0],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(64, 64, 64, 1),
          Color.fromRGBO(0, 0, 0, 1),
        ],
      ),
    );
  }

  // ── Standard dark card with subtle border ──
  static Widget networkingCard({
    required Widget child,
    EdgeInsets? padding,
    double borderRadius = 14,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: child,
    );
  }

  // ── Section title text ──
  static Widget sectionTitle(String title) {
    return Text(
      title,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  // ── Label/value detail row inside a card (auto-sizes with text) ──
  static Widget detailRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card with icon + label (auto-sizes with text) ──
  static Widget infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    double iconSize = 18,
  }) {
    return networkingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category badge with gradient and icon (auto-sizes with text) ──
  static Widget categoryBadge(String category, String? subcategory) {
    final colors = NetworkingConstants.getCategoryColors(category);
    final icon = NetworkingConstants.getCategoryIcon(category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors[0].withValues(alpha: 0.2),
            colors[1].withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors[0].withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: colors[0], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors[0],
                  ),
                ),
                if (subcategory != null && subcategory.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subcategory,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: colors[0].withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Expandable text card (for About Me, descriptions) ──
  static Widget textCard(String text, {String placeholder = 'Not set'}) {
    final hasText = text.isNotEmpty;
    return networkingCard(
      padding: const EdgeInsets.all(14),
      child: Text(
        hasText ? text : placeholder,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: hasText
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.4),
          height: 1.5,
        ),
      ),
    );
  }

  // ── Glassmorphic profile avatar card ──
  static Widget profileAvatarCard({
    required String name,
    required String? photoUrl,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: ClipOval(
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Colors.white54,
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name.isNotEmpty ? name : 'No Name',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state placeholder ──
  static Widget emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? buttonLabel,
    VoidCallback? onButtonTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            if (buttonLabel != null && onButtonTap != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF016CFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Bottom action button bar (blur background) ──
  static Widget bottomActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback? onTap,
    Color color = const Color(0xFF016CFF),
  }) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(30, 30, 30, 1),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: isLoading ? color.withValues(alpha: 0.5) : color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Glassmorphic label badge for card overlays (auto-sizes with text) ──
  // Use inside a Stack with Positioned — width grows with text content.
  static Widget glassBadge(
    String text, {
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    double blurSigma = 8,
    double borderRadius = 8,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    Color? backgroundColor,
    Color textColor = Colors.white,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }

  // ── Info chip with icon + label (for category, age, gender, distance) ──
  static Widget infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tag chip — text-only pill (for interests, subcategories) ──
  static Widget tagChip(
    String label, {
    IconData? icon,
    double fontSize = 12,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    double borderRadius = 20,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tag chip wrap — Wrap of tagChips from a list ──
  static Widget tagChipWrap(
    List<String> items, {
    IconData? icon,
    double spacing = 8,
    double runSpacing = 8,
  }) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: items
          .map((item) => tagChip(item, icon: icon))
          .toList(),
    );
  }

  // ── Standard loading indicator ──
  static Widget loadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white54,
        strokeWidth: 2,
      ),
    );
  }
}
