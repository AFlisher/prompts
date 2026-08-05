// test/data/credit_manager_test.dart
//
// Unit tests for CreditManager local storage logic

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/credit_manager.dart';

void main() {
  group('CreditManager', () {
    late CreditManager manager;

    setUpAll(() {
      // Required so path_provider can resolve directories in unit tests
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      manager = CreditManager();
    });

    test('initial credits value is 0', () {
      // Not a real balance - just the placeholder before the first
      // fetchWallet() resolves, so UI can tell "not loaded yet" apart from
      // an actual zero balance via isInitialized instead of guessing from
      // the number itself.
      expect(manager.credits, equals(0));
    });

    test('isInitialized starts as false', () {
      expect(manager.isInitialized, isFalse);
    });

    // Sprint 2 / B-3. The tests that used to live here exercised
    // addCredits()/useCredit() - the local credit-granting methods that backed
    // the simulated paywall. Both are deleted, so the tests are replaced rather
    // than adapted: what is worth asserting now is that no local path can move
    // the balance at all, and that the only writer is a value the server gave us.

    test('applyServerBalance sets the balance the server reported', () {
      manager.applyServerBalance(42);
      expect(manager.balance, equals(42));
      expect(manager.credits, equals(42));
    });

    test('applyServerBalance is idempotent - applying twice does not double', () {
      manager.applyServerBalance(42);
      manager.applyServerBalance(42);

      // The whole reason it takes an absolute value rather than a delta: a
      // retry or a rebuilt widget must not inflate the balance.
      expect(manager.balance, equals(42));
    });

    test('applyServerBalance can decrease the balance', () {
      manager.applyServerBalance(50);
      manager.applyServerBalance(10);
      expect(manager.balance, equals(10));
    });

    test('applyServerBalance ignores a negative balance', () {
      manager.applyServerBalance(10);
      manager.applyServerBalance(-5);
      expect(manager.balance, equals(10));
    });

    test('applyServerBalance notifies listeners', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);
      manager.applyServerBalance(7);
      expect(notifyCount, greaterThan(0));
    });

    test('clear resets the balance and the initialized flag', () {
      manager.applyServerBalance(99);
      manager.clear();
      expect(manager.balance, equals(0));
      expect(manager.isInitialized, isFalse);
    });

  });
}
