import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/data/favorites_manager.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('FavoritesManager', () {
    late FavoritesManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = FavoritesManager()..shouldSyncWithBackend = false;
    });

    test('initial favorites are empty', () {
      expect(manager.favoriteIds, isEmpty);
      expect(manager.isFavorite('style-1'), isFalse);
    });

    test('toggleFavorite adds a style and returns true', () {
      int count = 0;
      manager.addListener(() => count++);

      final result = manager.toggleFavorite('style-1');

      expect(result, isTrue);
      expect(manager.isFavorite('style-1'), isTrue);
      expect(manager.favoriteIds, contains('style-1'));
      expect(count, equals(1));
    });

    test('toggleFavorite removes an already-favorited style and returns false', () {
      manager.toggleFavorite('style-1');

      int count = 0;
      manager.addListener(() => count++);
      final result = manager.toggleFavorite('style-1');

      expect(result, isFalse);
      expect(manager.isFavorite('style-1'), isFalse);
      expect(count, equals(1));
    });

    test('favoriteIds is unmodifiable', () {
      manager.toggleFavorite('style-1');
      expect(() => manager.favoriteIds.add('style-2'), throwsUnsupportedError);
    });
  });
}
