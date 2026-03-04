import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/extended_user_profile.dart';
import 'package:supper/models/user_profile.dart';

void main() {
  group('ExtendedUserProfile - displayLocation', () {
    test('returns city when set', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        city: 'Mumbai',
        location: 'Maharashtra',
      );
      expect(profile.displayLocation, 'Mumbai');
    });

    test('returns location when city is null', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        location: 'Maharashtra',
      );
      expect(profile.displayLocation, 'Maharashtra');
    });

    test('returns Location not set when both null', () {
      final profile = ExtendedUserProfile(uid: 'uid', name: 'Test');
      expect(profile.displayLocation, 'Location not set');
    });

    test('returns Location not set when city is empty', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        city: '',
      );
      expect(profile.displayLocation, 'Location not set');
    });
  });

  group('ExtendedUserProfile - formattedDistance', () {
    test('returns null when distance is null', () {
      final profile = ExtendedUserProfile(uid: 'uid', name: 'Test');
      expect(profile.formattedDistance, isNull);
    });

    test('returns meters when distance < 1 km', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        distance: 0.5,
      );
      expect(profile.formattedDistance, '500 m away');
    });

    test('returns km when distance >= 1 km', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        distance: 3.7,
      );
      expect(profile.formattedDistance, '3.7 km away');
    });

    test('rounds meters to nearest integer', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        distance: 0.123,
      );
      expect(profile.formattedDistance, '123 m away');
    });
  });

  group('ExtendedUserProfile - hasConnectionType', () {
    test('returns true when type is present', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        connectionTypes: ['friendship', 'networking'],
      );
      expect(profile.hasConnectionType('friendship'), isTrue);
    });

    test('returns false when type is absent', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        connectionTypes: ['friendship'],
      );
      expect(profile.hasConnectionType('dating'), isFalse);
    });
  });

  group('ExtendedUserProfile - activityNames', () {
    test('returns list of activity names', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        activities: [
          Activity(name: 'Running'),
          Activity(name: 'Swimming'),
        ],
      );
      expect(profile.activityNames, ['Running', 'Swimming']);
    });

    test('returns empty list when no activities', () {
      final profile = ExtendedUserProfile(uid: 'uid', name: 'Test');
      expect(profile.activityNames, isEmpty);
    });
  });

  group('ExtendedUserProfile - helper getters', () {
    test('isBusiness returns true for business type', () {
      final profile = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        accountType: AccountType.business,
      );
      expect(profile.isBusiness, isTrue);
      expect(profile.isPersonal, isFalse);
    });

    test('isPersonal returns true for personal type', () {
      final profile = ExtendedUserProfile(uid: 'uid', name: 'Test');
      expect(profile.isPersonal, isTrue);
      expect(profile.isBusiness, isFalse);
    });

    test('isVerifiedAccount checks verification status', () {
      final verified = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        verificationStatus: VerificationStatus.verified,
      );
      expect(verified.isVerifiedAccount, isTrue);

      final unverified = ExtendedUserProfile(uid: 'uid', name: 'Test');
      expect(unverified.isVerifiedAccount, isFalse);
    });

    test('isPendingVerification checks pending status', () {
      final pending = ExtendedUserProfile(
        uid: 'uid',
        name: 'Test',
        verificationStatus: VerificationStatus.pending,
      );
      expect(pending.isPendingVerification, isTrue);
    });
  });

  group('ExtendedUserProfile - fromMap', () {
    test('parses legacy string activities', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Test',
        'activities': ['Running', 'Yoga'],
      }, 'uid');
      expect(profile.activityNames, ['Running', 'Yoga']);
    });

    test('parses map activities', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Test',
        'activities': [
          {'name': 'Swimming'},
          {'name': 'Chess'},
        ],
      }, 'uid');
      expect(profile.activityNames, ['Swimming', 'Chess']);
    });

    test('display name falls back to phone', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': '',
        'phone': '+919876543210',
      }, 'uid');
      expect(profile.name, '+919876543210');
    });

    test('display name falls back from User to phone', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'User',
        'phone': '+911234567890',
      }, 'uid');
      expect(profile.name, '+911234567890');
    });

    test('extracts business name from businessProfile', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Owner',
        'businessProfile': {
          'businessName': 'My Shop',
          'softLabel': 'Retail',
        },
      }, 'uid');
      expect(profile.businessName, 'My Shop');
      expect(profile.category, 'Retail');
    });

    test('extracts legacy business fields', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Owner',
        'businessProfile': {
          'companyName': 'Legacy Corp',
          'industry': 'Tech',
        },
      }, 'uid');
      expect(profile.businessName, 'Legacy Corp');
      expect(profile.category, 'Tech');
    });

    test('extracts verification status', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Test',
        'verification': {'status': 'verified'},
      }, 'uid');
      expect(profile.verificationStatus, VerificationStatus.verified);
    });

    test('defaults account type to personal', () {
      final profile = ExtendedUserProfile.fromMap({
        'name': 'Test',
      }, 'uid');
      expect(profile.accountType, AccountType.personal);
      expect(profile.accountStatus, AccountStatus.active);
    });
  });

  group('Activity', () {
    test('fromMap/toMap round-trip', () {
      final original = Activity(name: 'Hiking');
      final map = original.toMap();
      final restored = Activity.fromMap(map);
      expect(restored.name, 'Hiking');
    });

    test('toString returns name', () {
      expect(Activity(name: 'Chess').toString(), 'Chess');
    });
  });
}
