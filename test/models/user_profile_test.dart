import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/user_profile.dart';

void main() {
  group('AccountType', () {
    test('fromString parses business variants', () {
      expect(AccountType.fromString('business'), AccountType.business);
      expect(AccountType.fromString('Business'), AccountType.business);
      expect(AccountType.fromString('business account'), AccountType.business);
    });

    test('fromString defaults to personal', () {
      expect(AccountType.fromString(null), AccountType.personal);
      expect(AccountType.fromString('unknown'), AccountType.personal);
      expect(AccountType.fromString(''), AccountType.personal);
    });

    test('displayName returns correct labels', () {
      expect(AccountType.personal.displayName, 'Personal Account');
      expect(AccountType.business.displayName, 'Business Account');
    });
  });

  group('AccountStatus', () {
    test('fromString parses all statuses', () {
      expect(AccountStatus.fromString('suspended'), AccountStatus.suspended);
      expect(
        AccountStatus.fromString('pending_verification'),
        AccountStatus.pendingVerification,
      );
      expect(
        AccountStatus.fromString('pendingverification'),
        AccountStatus.pendingVerification,
      );
    });

    test('fromString defaults to active', () {
      expect(AccountStatus.fromString(null), AccountStatus.active);
      expect(AccountStatus.fromString('unknown'), AccountStatus.active);
    });

    test('displayName returns correct labels', () {
      expect(AccountStatus.active.displayName, 'Active');
      expect(
        AccountStatus.pendingVerification.displayName,
        'Pending Verification',
      );
      expect(AccountStatus.suspended.displayName, 'Suspended');
    });
  });

  group('VerificationStatus', () {
    test('fromString parses all statuses', () {
      expect(
        VerificationStatus.fromString('pending'),
        VerificationStatus.pending,
      );
      expect(
        VerificationStatus.fromString('verified'),
        VerificationStatus.verified,
      );
      expect(
        VerificationStatus.fromString('rejected'),
        VerificationStatus.rejected,
      );
    });

    test('fromString defaults to none', () {
      expect(VerificationStatus.fromString(null), VerificationStatus.none);
      expect(VerificationStatus.fromString('xyz'), VerificationStatus.none);
    });

    test('displayName returns correct labels', () {
      expect(VerificationStatus.none.displayName, 'Not Verified');
      expect(VerificationStatus.pending.displayName, 'Pending');
      expect(VerificationStatus.verified.displayName, 'Verified');
      expect(VerificationStatus.rejected.displayName, 'Rejected');
    });
  });

  group('DayHours', () {
    test('formatted shows open-close times', () {
      final hours = DayHours(open: '09:00', close: '18:00');
      expect(hours.formatted, '09:00 - 18:00');
    });

    test('formatted shows Closed when isClosed', () {
      final hours = DayHours(isClosed: true);
      expect(hours.formatted, 'Closed');
    });

    test('formatted shows Not set when times are null', () {
      final hours = DayHours();
      expect(hours.formatted, 'Not set');
    });

    test('fromMap creates correct instance', () {
      final hours = DayHours.fromMap({
        'open': '10:00',
        'close': '22:00',
        'isClosed': false,
      });
      expect(hours.open, '10:00');
      expect(hours.close, '22:00');
      expect(hours.isClosed, isFalse);
    });

    test('toMap round-trips correctly', () {
      final original = DayHours(open: '09:00', close: '17:00', isClosed: false);
      final map = original.toMap();
      final restored = DayHours.fromMap(map);
      expect(restored.open, original.open);
      expect(restored.close, original.close);
      expect(restored.isClosed, original.isClosed);
    });
  });

  group('BusinessHours', () {
    test('defaultHours creates Mon-Fri 9-18, Sat 10-16, Sun closed', () {
      final hours = BusinessHours.defaultHours();
      expect(hours.schedule['monday']!.open, '09:00');
      expect(hours.schedule['monday']!.close, '18:00');
      expect(hours.schedule['saturday']!.open, '10:00');
      expect(hours.schedule['saturday']!.close, '16:00');
      expect(hours.schedule['sunday']!.isClosed, isTrue);
    });

    test('fromMap creates schedule from nested map', () {
      final hours = BusinessHours.fromMap({
        'schedule': {
          'monday': {'open': '08:00', 'close': '20:00', 'isClosed': false},
          'tuesday': {'isClosed': true},
        },
        'timezone': 'Asia/Kolkata',
      });
      expect(hours.schedule['monday']!.open, '08:00');
      expect(hours.schedule['tuesday']!.isClosed, isTrue);
      expect(hours.timezone, 'Asia/Kolkata');
    });

    test('toMap round-trips correctly', () {
      final original = BusinessHours.defaultHours();
      final map = original.toMap();
      final restored = BusinessHours.fromMap(map);
      expect(restored.schedule.length, original.schedule.length);
      expect(restored.schedule['sunday']!.isClosed, isTrue);
    });
  });

  group('BusinessProfile', () {
    test('fromMap with null returns empty profile', () {
      final profile = BusinessProfile.fromMap(null);
      expect(profile.businessName, isNull);
      expect(profile.profileViews, 0);
      expect(profile.isLive, isFalse);
    });

    test('fromMap handles legacy field names', () {
      final profile = BusinessProfile.fromMap({
        'companyName': 'Legacy Corp',
        'industry': 'Technology',
      });
      expect(profile.businessName, 'Legacy Corp');
      expect(profile.softLabel, 'Technology');
    });

    test('fromMap prefers new field names over legacy', () {
      final profile = BusinessProfile.fromMap({
        'businessName': 'New Name',
        'companyName': 'Old Name',
        'softLabel': 'New Label',
        'industry': 'Old Label',
      });
      expect(profile.businessName, 'New Name');
      expect(profile.softLabel, 'New Label');
    });

    test('copyWith preserves unchanged fields', () {
      final original = BusinessProfile(
        businessName: 'Test',
        description: 'Desc',
        isLive: true,
        averageRating: 4.5,
      );
      final copy = original.copyWith(businessName: 'Updated');
      expect(copy.businessName, 'Updated');
      expect(copy.description, 'Desc');
      expect(copy.isLive, isTrue);
      expect(copy.averageRating, 4.5);
    });

    test('isCurrentlyOpen delegates to hours', () {
      final profile = BusinessProfile(hours: null);
      expect(profile.isCurrentlyOpen, isFalse);
    });
  });

  group('VerificationData', () {
    test('fromMap with null returns default', () {
      final data = VerificationData.fromMap(null);
      expect(data.status, VerificationStatus.none);
      expect(data.verifiedAt, isNull);
      expect(data.rejectionReason, isNull);
    });

    test('fromMap parses status correctly', () {
      final data = VerificationData.fromMap({'status': 'verified'});
      expect(data.status, VerificationStatus.verified);
    });

    test('toMap round-trips status', () {
      final original = VerificationData(status: VerificationStatus.pending);
      final map = original.toMap();
      expect(map['status'], 'pending');
    });
  });

  group('UserProfile', () {
    UserProfile makeProfile({
      String? name,
      String? phone,
      AccountType accountType = AccountType.personal,
      BusinessProfile? businessProfile,
      VerificationData? verification,
    }) {
      return UserProfile(
        uid: 'test-uid',
        name: name ?? 'Test User',
        email: 'test@test.com',
        createdAt: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 1, 1),
        accountType: accountType,
        businessProfile: businessProfile,
        verification: verification,
      );
    }

    test('isBusiness returns true when businessProfile is set', () {
      final profile = makeProfile(
        businessProfile: BusinessProfile(businessName: 'Shop'),
      );
      expect(profile.isBusiness, isTrue);
    });

    test('isBusiness returns false when businessProfile is null', () {
      final profile = makeProfile();
      expect(profile.isBusiness, isFalse);
    });

    test('isPersonal returns true for personal account type', () {
      expect(makeProfile().isPersonal, isTrue);
    });

    test('isVerifiedAccount checks verification status', () {
      final verified = makeProfile(
        verification: VerificationData(status: VerificationStatus.verified),
      );
      expect(verified.isVerifiedAccount, isTrue);

      final unverified = makeProfile();
      expect(unverified.isVerifiedAccount, isFalse);
    });

    test('isPendingVerification checks pending status', () {
      final pending = makeProfile(
        verification: VerificationData(status: VerificationStatus.pending),
      );
      expect(pending.isPendingVerification, isTrue);
    });

    test('photoUrl getter returns profileImageUrl', () {
      final profile = UserProfile(
        uid: 'uid',
        name: 'Test',
        email: 'e@e.com',
        createdAt: DateTime(2024),
        lastSeen: DateTime(2024),
        profileImageUrl: 'https://example.com/photo.jpg',
      );
      expect(profile.photoUrl, 'https://example.com/photo.jpg');
    });

    test('copyWith preserves unchanged fields', () {
      final original = makeProfile(name: 'Original');
      final copy = original.copyWith(name: 'Updated');
      expect(copy.name, 'Updated');
      expect(copy.email, 'test@test.com');
      expect(copy.uid, 'test-uid');
    });

    test('id defaults to uid', () {
      final profile = makeProfile();
      expect(profile.id, profile.uid);
    });
  });
}
