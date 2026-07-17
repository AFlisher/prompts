// Model serialization tests (QA_TEST_PLAN.md data-integrity coverage).
//
// The backend API tests assert the server's response *shapes*; these assert
// the Flutter client deserializes those exact shapes correctly - including the
// defensive defaults and num->int coercion the models rely on. Together they
// close the client<->server contract end to end.

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/models/style.dart';
import 'package:prombt_app/models/style_model.dart';
import 'package:prombt_app/models/wallet.dart';
import 'package:prombt_app/models/credit_pack.dart';
import 'package:prombt_app/models/category.dart';

void main() {
  group('Style.fromJson', () {
    test('parses a complete backend style payload', () {
      final s = Style.fromJson({
        'id': 's1',
        'name': 'Cyberpunk',
        'categoryId': 'c1',
        'prompt': 'neon city',
        'negativePrompt': 'blurry',
        'creditCost': 3,
        'coverImage': 'http://cdn/x.png',
        'isTrending': true,
        'isPremium': true,
        'isEnabled': false,
        'sortOrder': 5,
      });
      expect(s.id, 's1');
      expect(s.creditCost, 3);
      expect(s.isTrending, isTrue);
      expect(s.isEnabled, isFalse);
      expect(s.negativePrompt, 'blurry');
    });

    test('applies safe defaults for missing/null fields', () {
      final s = Style.fromJson({});
      expect(s.id, '');
      expect(s.creditCost, 1); // default cost
      expect(s.isEnabled, isTrue); // enabled by default
      expect(s.isTrending, isFalse);
      expect(s.negativePrompt, isNull);
    });

    test('coerces a numeric creditCost/sortOrder from double to int', () {
      final s = Style.fromJson({'creditCost': 2.0, 'sortOrder': 4.0});
      expect(s.creditCost, 2);
      expect(s.sortOrder, 4);
    });

    test('round-trips through toJson', () {
      final original = Style.fromJson({
        'id': 's9', 'name': 'N', 'categoryId': 'c', 'prompt': 'p',
        'creditCost': 2, 'coverImage': 'u', 'isTrending': false,
        'isPremium': false, 'isEnabled': true, 'sortOrder': 1,
      });
      final copy = Style.fromJson(original.toJson());
      expect(copy.id, original.id);
      expect(copy.creditCost, original.creditCost);
      expect(copy.isEnabled, original.isEnabled);
    });

    // Styles are cached locally as toJson() output; dynamic fields must
    // survive the round-trip or cached styles silently lose their form.
    test('round-trips dynamic fields through toJson', () {
      final original = Style.fromJson({
        'id': 's9', 'name': 'N', 'categoryId': 'c', 'creditCost': 1,
        'fields': [
          {
            'key': 'team', 'label': 'Football Team', 'type': 'text',
            'required': true, 'placeholder': 'Barcelona',
            'config': {'minLength': 2, 'maxLength': 40}, 'sortOrder': 0,
          },
          {
            'key': 'kit', 'label': 'Kit', 'type': 'dropdown',
            'options': [{'value': 'home', 'label': 'Home'}, {'value': 'away', 'label': 'Away'}],
            'sortOrder': 1,
          },
        ],
      });
      final copy = Style.fromJson(original.toJson());
      expect(copy.fields, hasLength(2));
      expect(copy.fields[0].key, 'team');
      expect(copy.fields[0].required, isTrue);
      expect(copy.fields[0].config['maxLength'], 40);
      expect(copy.fields[1].type, 'dropdown');
      expect(copy.fields[1].options.map((o) => o.value), ['home', 'away']);

      final model = StyleModel.fromJson(original.toStyleModel().toJson());
      expect(model.fields, hasLength(2));
      expect(model.fields[0].label, 'Football Team');
    });

    test('maps to the legacy StyleModel preserving premium/cost/cover', () {
      final m = Style.fromJson({
        'id': 's', 'name': 'N', 'coverImage': 'http://c/i.png',
        'isPremium': true, 'creditCost': 4, 'isTrending': true,
      }).toStyleModel();
      expect(m.isPro, isTrue);
      expect(m.imageUrl, 'http://c/i.png');
      expect(m.creditCost, 4);
      expect(m.isTrending, isTrue);
    });
  });

  group('Wallet.fromJson', () {
    test('parses balance/progress and defaults dailyLimitReached', () {
      final w = Wallet.fromJson({'balance': 7, 'adsProgress': 1, 'generatedImages': 3});
      expect(w.balance, 7);
      expect(w.adsProgress, 1);
      expect(w.generatedImages, 3);
      expect(w.dailyLimitReached, isFalse);
    });

    test('defaults everything to zero/false on an empty payload', () {
      final w = Wallet.fromJson({});
      expect(w.balance, 0);
      expect(w.dailyLimitReached, isFalse);
    });

    test('copyWith overrides only the given fields', () {
      final w = Wallet.fromJson({'balance': 5}).copyWith(balance: 10);
      expect(w.balance, 10);
      expect(w.adsProgress, 0);
    });
  });

  group('AdRewardResult.fromJson', () {
    test('parses a "rewarded" response', () {
      final r = AdRewardResult.fromJson({'rewarded': true, 'balance': 6, 'adsProgress': 0});
      expect(r.rewarded, isTrue);
      expect(r.balance, 6);
    });

    test('parses a daily-limit response with no balance field', () {
      final r = AdRewardResult.fromJson({'rewarded': false, 'dailyLimitReached': true});
      expect(r.rewarded, isFalse);
      expect(r.dailyLimitReached, isTrue);
      expect(r.balance, isNull);
    });
  });

  group('WalletTransaction.fromJson', () {
    test('parses a debit (negative amount) with an ISO date', () {
      final t = WalletTransaction.fromJson({
        'id': 't1', 'amount': -2, 'type': 'generation',
        'description': 'Image generated', 'createdAt': '2026-07-03T10:00:00Z',
      });
      expect(t.amount, -2);
      expect(t.type, 'generation');
      expect(t.createdAt.toUtc().year, 2026);
    });

    test('accepts every ledger type without a description', () {
      for (final type in ['reward', 'purchase', 'generation', 'refund', 'admin']) {
        final t = WalletTransaction.fromJson({'id': 'x', 'amount': 1, 'type': type, 'createdAt': '2026-07-03T10:00:00Z'});
        expect(t.type, type);
        expect(t.description, isNull);
      }
    });
  });

  group('CreditPack.fromJson', () {
    test('parses required fields and optional badge/description', () {
      final p = CreditPack.fromJson({'id': 'p1', 'name': 'Starter', 'credits': 10, 'priceDisplay': '\$4.99', 'badge': 'Popular'});
      expect(p.credits, 10);
      expect(p.badge, 'Popular');
      expect(p.description, isNull);
    });
  });

  group('Category.fromJson', () {
    test('parses and defaults isEnabled to true', () {
      expect(Category.fromJson({'id': 'c', 'name': 'Portraits'}).isEnabled, isTrue);
      expect(Category.fromJson({'id': 'c', 'name': 'X', 'isEnabled': false}).isEnabled, isFalse);
    });
  });
}
