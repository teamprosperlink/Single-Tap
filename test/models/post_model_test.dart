import 'package:flutter_test/flutter_test.dart';
import 'package:supper/models/post_model.dart';

/// Helper to create a PostModel with minimal required fields
PostModel _makePost({
  String id = 'test-id',
  String userId = 'user-1',
  String originalPrompt = 'test prompt',
  Map<String, dynamic> intentAnalysis = const {},
  double? price,
  double? priceMin,
  double? priceMax,
}) {
  return PostModel(
    id: id,
    userId: userId,
    originalPrompt: originalPrompt,
    title: originalPrompt,
    description: '',
    intentAnalysis: intentAnalysis,
    metadata: {},
    createdAt: DateTime(2024, 1, 1),
    clarificationAnswers: {},
    price: price,
    priceMin: priceMin,
    priceMax: priceMax,
  );
}

void main() {
  group('PostModel - matchesIntent', () {
    test('offering matches seeking', () {
      final a = _makePost(intentAnalysis: {'action_type': 'offering'});
      final b = _makePost(intentAnalysis: {'action_type': 'seeking'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('selling matches buying', () {
      final a = _makePost(intentAnalysis: {'action_type': 'selling'});
      final b = _makePost(intentAnalysis: {'action_type': 'buying'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('giving matches requesting', () {
      final a = _makePost(intentAnalysis: {'action_type': 'giving'});
      final b = _makePost(intentAnalysis: {'action_type': 'requesting'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('lost matches found', () {
      final a = _makePost(intentAnalysis: {'action_type': 'lost'});
      final b = _makePost(intentAnalysis: {'action_type': 'found'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('hiring matches job_seeking', () {
      final a = _makePost(intentAnalysis: {'action_type': 'hiring'});
      final b = _makePost(intentAnalysis: {'action_type': 'job_seeking'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('renting matches rent_seeking', () {
      final a = _makePost(intentAnalysis: {'action_type': 'renting'});
      final b = _makePost(intentAnalysis: {'action_type': 'rent_seeking'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('symmetric intents with same action type match', () {
      final a = _makePost(intentAnalysis: {
        'action_type': 'seeking',
        'is_symmetric': true,
      });
      final b = _makePost(intentAnalysis: {
        'action_type': 'seeking',
        'is_symmetric': true,
      });
      expect(a.matchesIntent(b), isTrue);
    });

    test('exchange model incompatibility: free vs paid returns false', () {
      final a = _makePost(intentAnalysis: {
        'action_type': 'offering',
        'exchange_model': 'free',
      });
      final b = _makePost(intentAnalysis: {
        'action_type': 'seeking',
        'exchange_model': 'paid',
      });
      expect(a.matchesIntent(b), isFalse);
    });

    test('exchange model incompatibility: equity vs paid returns false', () {
      final a = _makePost(intentAnalysis: {
        'action_type': 'offering',
        'exchange_model': 'equity',
      });
      final b = _makePost(intentAnalysis: {
        'action_type': 'seeking',
        'exchange_model': 'paid',
      });
      expect(a.matchesIntent(b), isFalse);
    });

    test('same non-symmetric, non-legacy action type returns false', () {
      final a = _makePost(intentAnalysis: {'action_type': 'selling'});
      final b = _makePost(intentAnalysis: {'action_type': 'selling'});
      expect(a.matchesIntent(b), isFalse);
    });

    test('neutral action type always matches', () {
      final a = _makePost(intentAnalysis: {'action_type': 'neutral'});
      final b = _makePost(intentAnalysis: {'action_type': 'selling'});
      expect(a.matchesIntent(b), isTrue);
      expect(b.matchesIntent(a), isTrue);
    });

    test('legacy symmetric types: meetup matches meetup', () {
      final a = _makePost(intentAnalysis: {'action_type': 'meetup'});
      final b = _makePost(intentAnalysis: {'action_type': 'meetup'});
      expect(a.matchesIntent(b), isTrue);
    });

    test('legacy symmetric types: dating matches dating', () {
      final a = _makePost(intentAnalysis: {'action_type': 'dating'});
      final b = _makePost(intentAnalysis: {'action_type': 'dating'});
      expect(a.matchesIntent(b), isTrue);
    });

    test('legacy symmetric types: friendship matches friendship', () {
      final a = _makePost(intentAnalysis: {'action_type': 'friendship'});
      final b = _makePost(intentAnalysis: {'action_type': 'friendship'});
      expect(a.matchesIntent(b), isTrue);
    });

    test('legacy symmetric types: connecting matches connecting', () {
      final a = _makePost(intentAnalysis: {'action_type': 'connecting'});
      final b = _makePost(intentAnalysis: {'action_type': 'connecting'});
      expect(a.matchesIntent(b), isTrue);
    });

    test('unrelated action types return false', () {
      final a = _makePost(intentAnalysis: {'action_type': 'hiring'});
      final b = _makePost(intentAnalysis: {'action_type': 'selling'});
      expect(a.matchesIntent(b), isFalse);
    });
  });

  group('PostModel - matchesPrice', () {
    test('both no price returns true', () {
      final a = _makePost(intentAnalysis: {'action_type': 'selling'});
      final b = _makePost(intentAnalysis: {'action_type': 'buying'});
      expect(a.matchesPrice(b), isTrue);
    });

    test('seller price within buyer max', () {
      final seller = _makePost(
        intentAnalysis: {'action_type': 'selling'},
        price: 50,
      );
      final buyer = _makePost(
        intentAnalysis: {'action_type': 'buying'},
        priceMax: 100,
      );
      expect(seller.matchesPrice(buyer), isTrue);
    });

    test('seller price above buyer max returns false', () {
      final seller = _makePost(
        intentAnalysis: {'action_type': 'selling'},
        price: 150,
      );
      final buyer = _makePost(
        intentAnalysis: {'action_type': 'buying'},
        priceMax: 100,
      );
      expect(seller.matchesPrice(buyer), isFalse);
    });

    test('seller price within buyer min-max range', () {
      final seller = _makePost(
        intentAnalysis: {'action_type': 'selling'},
        price: 75,
      );
      final buyer = _makePost(
        intentAnalysis: {'action_type': 'buying'},
        priceMin: 50,
        priceMax: 100,
      );
      expect(seller.matchesPrice(buyer), isTrue);
    });

    test('seller price below buyer min returns false', () {
      final seller = _makePost(
        intentAnalysis: {'action_type': 'selling'},
        price: 30,
      );
      final buyer = _makePost(
        intentAnalysis: {'action_type': 'buying'},
        priceMin: 50,
        priceMax: 100,
      );
      expect(seller.matchesPrice(buyer), isFalse);
    });

    test('reversed roles: buyer range includes seller price', () {
      final buyer = _makePost(
        intentAnalysis: {'action_type': 'buying'},
        priceMax: 100,
      );
      final seller = _makePost(
        intentAnalysis: {'action_type': 'selling'},
        price: 80,
      );
      expect(buyer.matchesPrice(seller), isTrue);
    });

    test('only one side has price returns true', () {
      final a = _makePost(
        intentAnalysis: {'action_type': 'meetup'},
        price: 50,
      );
      final b = _makePost(intentAnalysis: {'action_type': 'meetup'});
      expect(a.matchesPrice(b), isTrue);
    });
  });

  group('PostModel - computed getters', () {
    test('primaryIntent returns primary_intent from analysis', () {
      final post = _makePost(intentAnalysis: {
        'primary_intent': 'find_plumber',
      });
      expect(post.primaryIntent, 'find_plumber');
    });

    test('primaryIntent falls back to originalPrompt', () {
      final post = _makePost(
        originalPrompt: 'I need a plumber',
        intentAnalysis: {},
      );
      expect(post.primaryIntent, 'I need a plumber');
    });

    test('actionType returns action_type from analysis', () {
      final post = _makePost(intentAnalysis: {'action_type': 'seeking'});
      expect(post.actionType, 'seeking');
    });

    test('actionType defaults to neutral', () {
      final post = _makePost(intentAnalysis: {});
      expect(post.actionType, 'neutral');
    });

    test('searchKeywords returns list from analysis', () {
      final post = _makePost(intentAnalysis: {
        'search_keywords': ['plumber', 'repair', 'pipe'],
      });
      expect(post.searchKeywords, ['plumber', 'repair', 'pipe']);
    });

    test('searchKeywords falls back to split original prompt', () {
      final post = _makePost(
        originalPrompt: 'need a plumber',
        intentAnalysis: {},
      );
      expect(post.searchKeywords, ['need', 'a', 'plumber']);
    });

    test('categoryDisplay formats domain for display', () {
      final post = _makePost(intentAnalysis: {'domain': 'home_services'});
      expect(post.categoryDisplay, 'Home Services');
    });

    test('intentDisplay formats action_type for display', () {
      final post = _makePost(intentAnalysis: {'action_type': 'job_seeking'});
      expect(post.intentDisplay, 'Job Seeking');
    });

    test('emotionalTone returns tone or defaults to casual', () {
      final withTone = _makePost(intentAnalysis: {'emotional_tone': 'urgent'});
      expect(withTone.emotionalTone, 'urgent');

      final withoutTone = _makePost(intentAnalysis: {});
      expect(withoutTone.emotionalTone, 'casual');
    });

    test('needsClarification returns true when clarifications exist', () {
      final needs = _makePost(intentAnalysis: {
        'clarifications_needed': ['What area?', 'Budget?'],
      });
      expect(needs.needsClarification, isTrue);

      final doesnt = _makePost(intentAnalysis: {
        'clarifications_needed': [],
      });
      expect(doesnt.needsClarification, isFalse);

      final missing = _makePost(intentAnalysis: {});
      expect(missing.needsClarification, isFalse);
    });

    test('entities returns entities map or empty', () {
      final post = _makePost(intentAnalysis: {
        'entities': {'location': 'Mumbai', 'service': 'plumbing'},
      });
      expect(post.entities['location'], 'Mumbai');

      final empty = _makePost(intentAnalysis: {});
      expect(empty.entities, isEmpty);
    });
  });
}
