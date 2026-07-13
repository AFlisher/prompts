import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/creations_manager.dart';

void main() {
  group('CreationsManager', () {
    late CreationsManager manager;

    setUp(() {
      manager = CreationsManager()
        ..shouldSaveToFile = false
        ..shouldSyncWithBackend = false;
    });

    test('initial creations list is empty', () {
      expect(manager.creations, isEmpty);
      expect(manager.currentTab, equals(0));
    });

    test('addCreation adds an item and triggers notifyListeners', () async {
      int count = 0;
      manager.addListener(() => count++);

      final item = CreationItem(
        id: 'test_id',
        styleId: 'comic',
        styleName: 'Comic Style',
        imagePath: 'assets/images/style1.jpg',
        createdAt: DateTime.now(),
      );

      await manager.addCreation(item);

      expect(manager.creations.length, equals(1));
      expect(manager.creations.first.id, equals('test_id'));
      expect(count, equals(1));
    });

    test('deleteCreation removes an item and triggers notifyListeners', () async {
      final item1 = CreationItem(
        id: 'id1',
        styleId: 'comic',
        styleName: 'Comic Style',
        imagePath: 'assets/images/style1.jpg',
        createdAt: DateTime.now(),
      );
      final item2 = CreationItem(
        id: 'id2',
        styleId: 'neon',
        styleName: 'Neon Style',
        imagePath: 'assets/images/style2.jpg',
        createdAt: DateTime.now(),
      );

      await manager.addCreation(item1);
      await manager.addCreation(item2);
      expect(manager.creations.length, equals(2));

      int count = 0;
      manager.addListener(() => count++);

      await manager.deleteCreation('id1');

      expect(manager.creations.length, equals(1));
      expect(manager.creations.first.id, equals('id2'));
      expect(count, equals(1));
    });

    test('setTab updates currentTab and triggers notifyListeners', () {
      int count = 0;
      manager.addListener(() => count++);

      manager.setTab(1);
      expect(manager.currentTab, equals(1));
      expect(count, equals(1));

      // Same tab shouldn't notify
      manager.setTab(1);
      expect(count, equals(1));
    });
  });

  group('CreationItem.fromJson', () {
    test('parses the local-JSON-file shape (imagePath)', () {
      final item = CreationItem.fromJson({
        'id': 'id1',
        'styleId': 'comic',
        'styleName': 'Comic Style',
        'imagePath': 'assets/images/style1.jpg',
        'createdAt': '2024-01-01T00:00:00.000Z',
      });

      expect(item.imagePath, equals('assets/images/style1.jpg'));
      expect(item.styleId, equals('comic'));
    });

    test('parses the backend API shape (imageUrl) as the same field', () {
      final item = CreationItem.fromJson({
        'id': 'id1',
        'styleId': 'comic',
        'styleName': 'Comic Style',
        'imageUrl': 'https://example.com/generated.png',
        'createdAt': '2024-01-01T00:00:00.000Z',
      });

      expect(item.imagePath, equals('https://example.com/generated.png'));
    });

    test('defaults styleId to an empty string when null (style was deleted server-side)', () {
      final item = CreationItem.fromJson({
        'id': 'id1',
        'styleId': null,
        'styleName': 'Comic Style',
        'imageUrl': 'https://example.com/generated.png',
        'createdAt': '2024-01-01T00:00:00.000Z',
      });

      expect(item.styleId, equals(''));
    });
  });
}
