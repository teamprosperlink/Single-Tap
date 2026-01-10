import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

/// Verified badge - blue checkmark for verified accounts
class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showBackground;

  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.verified,
      size: size,
      color: Colors.blue,
    );

    if (!showBackground) return icon;

    return Container(
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }
}

/// Professional badge - purple badge for professional accounts
class ProfessionalBadge extends StatelessWidget {
  final double size;
  final bool showLabel;
  final bool compact;

  const ProfessionalBadge({
    super.key,
    this.size = 16,
    this.showLabel = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              size: size * 0.75,
              color: const Color(0xFF9C27B0),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                'PRO',
                style: TextStyle(
                  color: const Color(0xFF9C27B0),
                  fontSize: size * 0.65,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0).withValues(alpha: 0.2),
            const Color(0xFF7B1FA2).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: size,
            color: const Color(0xFF9C27B0),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Professional',
              style: TextStyle(
                color: const Color(0xFF9C27B0),
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Business badge - gold/orange badge for business accounts
class BusinessBadge extends StatelessWidget {
  final double size;
  final bool showLabel;
  final bool compact;

  const BusinessBadge({
    super.key,
    this.size = 16,
    this.showLabel = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business,
              size: size * 0.75,
              color: const Color(0xFFFF9800),
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                'BIZ',
                style: TextStyle(
                  color: const Color(0xFFFF9800),
                  fontSize: size * 0.65,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFB300).withValues(alpha: 0.2),
            const Color(0xFFFF9800).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business,
            size: size,
            color: const Color(0xFFFF9800),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Business',
              style: TextStyle(
                color: const Color(0xFFFF9800),
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pending verification badge - yellow badge for accounts pending verification
class PendingVerificationBadge extends StatelessWidget {
  final double size;
  final bool showLabel;

  const PendingVerificationBadge({
    super.key,
    this.size = 16,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 8 : 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pending,
            size: size,
            color: Colors.amber[700],
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.amber[700],
                fontSize: size * 0.75,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Smart badge that automatically shows the correct badge based on account type
class AccountTypeBadge extends StatelessWidget {
  final AccountType accountType;
  final VerificationStatus verificationStatus;
  final double size;
  final bool showLabel;
  final bool compact;

  const AccountTypeBadge({
    super.key,
    required this.accountType,
    this.verificationStatus = VerificationStatus.none,
    this.size = 16,
    this.showLabel = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // For personal accounts, only show verified badge if they're verified
    if (accountType == AccountType.personal) {
      if (verificationStatus == VerificationStatus.verified) {
        return VerifiedBadge(size: size);
      }
      return const SizedBox.shrink();
    }

    // For professional/business accounts
    final isVerified = verificationStatus == VerificationStatus.verified;
    final isPending = verificationStatus == VerificationStatus.pending;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Account type badge
        if (accountType == AccountType.professional)
          ProfessionalBadge(size: size, showLabel: showLabel, compact: compact)
        else if (accountType == AccountType.business)
          BusinessBadge(size: size, showLabel: showLabel, compact: compact),

        // Verification status
        if (isVerified) ...[
          const SizedBox(width: 4),
          VerifiedBadge(size: size * 0.9),
        ] else if (isPending) ...[
          const SizedBox(width: 4),
          PendingVerificationBadge(size: size * 0.9, showLabel: false),
        ],
      ],
    );
  }
}

/// Inline badge to show next to username
class UsernameBadge extends StatelessWidget {
  final AccountType accountType;
  final VerificationStatus verificationStatus;
  final double size;

  const UsernameBadge({
    super.key,
    required this.accountType,
    this.verificationStatus = VerificationStatus.none,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = verificationStatus == VerificationStatus.verified;

    // Personal accounts - only show verified badge if verified
    if (accountType == AccountType.personal) {
      if (isVerified) {
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: VerifiedBadge(size: size),
        );
      }
      return const SizedBox.shrink();
    }

    // Professional/Business accounts - show type indicator
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accountType == AccountType.professional)
            Icon(
              Icons.workspace_premium,
              size: size,
              color: const Color(0xFF9C27B0),
            )
          else if (accountType == AccountType.business)
            Icon(
              Icons.business,
              size: size,
              color: const Color(0xFFFF9800),
            ),
          if (isVerified) ...[
            const SizedBox(width: 2),
            VerifiedBadge(size: size * 0.9),
          ],
        ],
      ),
    );
  }
}

/// Glassmorphism account type card for profile display
class AccountTypeCard extends StatelessWidget {
  final AccountType accountType;
  final VerificationStatus verificationStatus;
  final VoidCallback? onUpgrade;

  const AccountTypeCard({
    super.key,
    required this.accountType,
    this.verificationStatus = VerificationStatus.none,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = verificationStatus == VerificationStatus.verified;
    final isPending = verificationStatus == VerificationStatus.pending;

    Color primaryColor;
    IconData icon;
    String title;
    String subtitle;

    switch (accountType) {
      case AccountType.personal:
        primaryColor = Colors.blue;
        icon = Icons.person;
        title = 'Personal Account';
        subtitle = 'For individual buyers and sellers';
        break;
      case AccountType.professional:
        primaryColor = const Color(0xFF9C27B0);
        icon = Icons.workspace_premium;
        title = 'Professional Account';
        subtitle = 'Freelancer & Service Provider';
        break;
      case AccountType.business:
        primaryColor = const Color(0xFFFF9800);
        icon = Icons.business;
        title = 'Business Account';
        subtitle = 'Business & Organization';
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pending,
                              size: 14,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verification Pending',
                              style: TextStyle(
                                color: Colors.amber[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onUpgrade != null && accountType == AccountType.personal)
                TextButton(
                  onPressed: onUpgrade,
                  child: const Text('Upgrade'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
