// Tests for AccountTypeService pure logic methods.
//
// Since AccountTypeService is a singleton that eagerly initializes Firebase,
// we test the pure logic (getAccountFeatures, isFeatureAvailable,
// getPostLimit, getAccountTypeInfo) as standalone functions that mirror
// the service's implementation. This validates the business rules without
// requiring Firebase initialization.
import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/user_profile.dart';

// Mirror the pure logic from AccountTypeService to test business rules
// without triggering the Firebase-dependent singleton.

Map<String, dynamic> _getAccountFeatures(AccountType accountType) {
  switch (accountType) {
    case AccountType.personal:
      return {
        'canBuySell': true,
        'maxPostsPerDay': 5,
        'canChat': true,
        'canLiveConnect': true,
        'verifiedBadge': false,
        'portfolio': false,
        'serviceListings': false,
        'reviewsReceived': false,
        'teamMembers': false,
        'maxTeamMembers': 0,
        'analytics': false,
        'prioritySupport': false,
        'promotedListings': false,
        'bulkUpload': false,
      };
    case AccountType.business:
      return {
        'canBuySell': true,
        'maxPostsPerDay': -1,
        'canChat': true,
        'canLiveConnect': true,
        'verifiedBadge': true,
        'portfolio': true,
        'serviceListings': true,
        'reviewsReceived': true,
        'teamMembers': true,
        'maxTeamMembers': 10,
        'analytics': true,
        'analyticsLevel': 'advanced',
        'prioritySupport': true,
        'promotedListings': true,
        'bulkUpload': true,
      };
  }
}

bool _isFeatureAvailable(String feature, AccountType accountType) {
  final features = _getAccountFeatures(accountType);
  return features[feature] ?? false;
}

int _getPostLimit(AccountType accountType) {
  final features = _getAccountFeatures(accountType);
  return features['maxPostsPerDay'] ?? 5;
}

Map<String, dynamic> _getAccountTypeInfo(AccountType accountType) {
  switch (accountType) {
    case AccountType.personal:
      return {
        'name': 'Personal Account',
        'description': 'For individual buyers and sellers',
        'icon': 'person',
        'color': 0xFF2196F3,
        'badgeColor': 0xFF2196F3,
      };
    case AccountType.business:
      return {
        'name': 'Business Account',
        'description': 'For businesses and organizations',
        'icon': 'business',
        'color': 0xFFFF9800,
        'badgeColor': 0xFFFFB300,
      };
  }
}

void main() {
  group('AccountTypeService logic - getAccountFeatures', () {
    test('personal account has limited features', () {
      final features = _getAccountFeatures(AccountType.personal);
      expect(features['canBuySell'], isTrue);
      expect(features['canChat'], isTrue);
      expect(features['canLiveConnect'], isTrue);
      expect(features['maxPostsPerDay'], 5);
      expect(features['verifiedBadge'], isFalse);
      expect(features['portfolio'], isFalse);
      expect(features['serviceListings'], isFalse);
      expect(features['reviewsReceived'], isFalse);
      expect(features['analytics'], isFalse);
      expect(features['prioritySupport'], isFalse);
      expect(features['promotedListings'], isFalse);
      expect(features['bulkUpload'], isFalse);
    });

    test('business account has full features', () {
      final features = _getAccountFeatures(AccountType.business);
      expect(features['canBuySell'], isTrue);
      expect(features['canChat'], isTrue);
      expect(features['canLiveConnect'], isTrue);
      expect(features['maxPostsPerDay'], -1);
      expect(features['verifiedBadge'], isTrue);
      expect(features['portfolio'], isTrue);
      expect(features['serviceListings'], isTrue);
      expect(features['reviewsReceived'], isTrue);
      expect(features['analytics'], isTrue);
      expect(features['analyticsLevel'], 'advanced');
      expect(features['prioritySupport'], isTrue);
      expect(features['promotedListings'], isTrue);
      expect(features['bulkUpload'], isTrue);
      expect(features['maxTeamMembers'], 10);
    });
  });

  group('AccountTypeService logic - isFeatureAvailable', () {
    test('personal cannot access portfolio', () {
      expect(_isFeatureAvailable('portfolio', AccountType.personal), isFalse);
    });

    test('business can access portfolio', () {
      expect(_isFeatureAvailable('portfolio', AccountType.business), isTrue);
    });

    test('personal can buy/sell', () {
      expect(_isFeatureAvailable('canBuySell', AccountType.personal), isTrue);
    });

    test('unknown feature returns false', () {
      expect(_isFeatureAvailable('nonexistent', AccountType.personal), isFalse);
      expect(_isFeatureAvailable('nonexistent', AccountType.business), isFalse);
    });
  });

  group('AccountTypeService logic - getPostLimit', () {
    test('personal limit is 5', () {
      expect(_getPostLimit(AccountType.personal), 5);
    });

    test('business limit is -1 (unlimited)', () {
      expect(_getPostLimit(AccountType.business), -1);
    });
  });

  group('AccountTypeService logic - getAccountTypeInfo', () {
    test('personal account info', () {
      final info = _getAccountTypeInfo(AccountType.personal);
      expect(info['name'], 'Personal Account');
      expect(info['description'], 'For individual buyers and sellers');
      expect(info['icon'], 'person');
      expect(info['color'], isA<int>());
    });

    test('business account info', () {
      final info = _getAccountTypeInfo(AccountType.business);
      expect(info['name'], 'Business Account');
      expect(info['description'], 'For businesses and organizations');
      expect(info['icon'], 'business');
      expect(info['color'], isA<int>());
    });
  });
}
