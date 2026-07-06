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

    test('initial credits value is 3', () {
      expect(manager.credits, equals(3));
    });

    test('isInitialized starts as false', () {
      expect(manager.isInitialized, isFalse);
    });

    test('useCredit decrements credits by 1', () {
      final initial = manager.credits;
      manager.useCredit();
      expect(manager.credits, equals(initial - 1));
    });

    test('useCredit returns true when credits available', () {
      final result = manager.useCredit();
      expect(result, isTrue);
    });

    test('useCredit returns false when credits are 0', () {
      // Drain all credits
      while (manager.credits > 0) {
        manager.useCredit();
      }
      final result = manager.useCredit();
      expect(result, isFalse);
    });

    test('credits never go below 0', () {
      // Drain all credits
      while (manager.credits > 0) {
        manager.useCredit();
      }
      manager.useCredit(); // should not go below 0
      expect(manager.credits, equals(0));
    });

    test('addCredits increases credit balance', () async {
      final before = manager.credits;
      await manager.addCredits(10);
      expect(manager.credits, equals(before + 10));
    });

    test('addCredits with large amount works correctly', () async {
      await manager.addCredits(100);
      expect(manager.credits, equals(103)); // 3 initial + 100
    });

    test('notifyListeners is called after useCredit', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);
      manager.useCredit();
      expect(notifyCount, greaterThan(0));
    });

    test('notifyListeners is called after addCredits', () async {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);
      await manager.addCredits(5);
      expect(notifyCount, greaterThan(0));
    });
  });
}
