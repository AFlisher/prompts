// Sprint 2 / B-6 — cursor pagination in CreationsManager.
//
// The bug this closes was silent: the backend has always returned at most 50
// creations plus `X-Next-Cursor`/`X-Has-More` headers, and the client read
// neither. A user with 51 generated images could never reach the first one,
// with nothing in the UI to suggest anything was missing - images they had
// spent credits to create.

import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves canned pages and records how it was called.
class FakeApiService implements ApiService {
  FakeApiService(this.pages);

  /// cursor -> page. The first page is keyed by null.
  final Map<String?, ({List<Map<String, dynamic>> items, String? nextCursor, bool hasMore})> pages;

  final List<String?> requestedCursors = [];
  final List<int> requestedLimits = [];
  int failuresToInject = 0;

  @override
  Future<({List<Map<String, dynamic>> items, String? nextCursor, bool hasMore})>
      getCreationsPage({int limit = 30, String? cursor}) async {
    requestedCursors.add(cursor);
    requestedLimits.add(limit);

    if (failuresToInject > 0) {
      failuresToInject -= 1;
      throw Exception('network down');
    }

    return pages[cursor] ??
        (items: <Map<String, dynamic>>[], nextCursor: null, hasMore: false);
  }

  @override
  Future<List<Map<String, dynamic>>> getCreations() async {
    final page = await getCreationsPage();
    return page.items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> creationJson(String id) => {
      'id': id,
      'styleId': 'style-1',
      'styleName': 'Style One',
      'imagePath': 'https://example.com/$id.png',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  CreationsManager managerWith(FakeApiService api) =>
      CreationsManager(apiService: api)
        ..shouldSaveToFile = false
        ..shouldSyncWithBackend = false;

  group('bounded requests', () {
    test('never asks for an unbounded page', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      });

      // Priming the first page through the public paging entry point.
      final manager = managerWith(api);
      await manager.refresh();
      await manager.loadMore();

      expect(api.requestedLimits, isNotEmpty);
      for (final limit in api.requestedLimits) {
        expect(limit, greaterThan(0));
        expect(limit, lessThanOrEqualTo(100),
            reason: 'the backend clamps at 100; asking for more is pointless');
      }
    });
  });

  group('paging forward', () {
    test('reads the cursor from the first page and uses it for the next',
        () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'cursor-1', hasMore: true),
        'cursor-1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);

      await manager.refresh();
      expect(manager.hasMore, isTrue);

      await manager.loadMore();

      expect(api.requestedCursors, equals([null, 'cursor-1']));
      expect(manager.creations.map((c) => c.id), equals(['a', 'b']));
    });

    test('appends rather than replacing', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a'), creationJson('b')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('c')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);

      await manager.refresh();
      await manager.loadMore();

      expect(manager.creations, hasLength(3));
    });

    test('stops when the server says there is no more', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);

      await manager.refresh();
      await manager.loadMore();
      expect(manager.hasMore, isFalse);

      await manager.loadMore();
      // No third request - the scroll listener calls this constantly.
      expect(api.requestedCursors, hasLength(2));
    });
  });

  group('re-entrancy', () {
    test('concurrent loadMore calls issue only one request', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);
      await manager.refresh();

      // A fling near the bottom fires the scroll notification many times.
      await Future.wait([
        manager.loadMore(),
        manager.loadMore(),
        manager.loadMore(),
      ]);

      expect(api.requestedCursors, equals([null, 'c1']));
    });

    test('does nothing when there is no cursor', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);
      await manager.refresh();

      await manager.loadMore();
      expect(api.requestedCursors, equals([null]));
    });
  });

  group('duplicates', () {
    test('a creation already present is not added twice', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        // The server page overlaps with what is already loaded - which happens
        // when the user generates an image while scrolling.
        'c1': (items: [creationJson('a'), creationJson('b')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);

      await manager.refresh();
      await manager.loadMore();

      expect(manager.creations.map((c) => c.id), equals(['a', 'b']));
    });
  });

  group('failure handling', () {
    test('keeps the pages already loaded when a page fails', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      })
        ..failuresToInject = 0;

      final manager = managerWith(api);
      await manager.refresh();

      api.failuresToInject = 1;
      await manager.loadMore();

      // The gallery must not empty itself over a dropped connection.
      expect(manager.creations.map((c) => c.id), equals(['a']));
    });

    test('a failed page can be retried', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
        'c1': (items: [creationJson('b')], nextCursor: null, hasMore: false),
      });
      final manager = managerWith(api);
      await manager.refresh();

      api.failuresToInject = 1;
      await manager.loadMore();
      expect(manager.hasMore, isTrue, reason: 'a failure must not end pagination');

      await manager.loadMore();
      expect(manager.creations.map((c) => c.id), equals(['a', 'b']));
    });

    test('isLoadingMore is reset after a failure', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
      })
        ..failuresToInject = 0;
      final manager = managerWith(api);
      await manager.refresh();

      api.failuresToInject = 1;
      await manager.loadMore();

      // Left true, pagination would be permanently stuck.
      expect(manager.isLoadingMore, isFalse);
    });
  });

  group('clear', () {
    test('resets paging state so the next account starts from page one', () async {
      final api = FakeApiService({
        null: (items: [creationJson('a')], nextCursor: 'c1', hasMore: true),
      });
      final manager = managerWith(api);
      await manager.refresh();
      expect(manager.hasMore, isTrue);

      manager.clear();

      expect(manager.creations, isEmpty);
      expect(manager.hasMore, isFalse);
      expect(manager.isLoadingMore, isFalse);
    });
  });
}
