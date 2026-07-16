// test/screens/home/notifications_screen_test.dart
//
// NotificationsScreen now renders the real backend feed via
// NotificationsManager (loading / error / empty / grouped list states),
// and the Profile screen shows an unread badge that follows the manager.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/data/notifications_manager.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/models/notification_model.dart';
import 'package:prombt_app/screens/notifications_screen.dart';
import 'package:prombt_app/screens/profile_screen.dart';

AppNotification _notification({
  String id = 'n1',
  String type = 'welcome',
  String title = 'Welcome to StyliAI',
  String body = 'Start exploring styles.',
  bool isRead = false,
  DateTime? createdAt,
}) {
  return AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

Future<NotificationsManager> _seededManager(
  List<AppNotification> items,
  int unread,
) async {
  final manager = NotificationsManager();
  manager.fetchOverride = () async => (notifications: items, unreadCount: unread);
  await manager.fetch();
  return manager;
}

Widget _wrap(NotificationsManager manager, Widget child) {
  final favManager = FavoritesManager();
  final styleManager = DynamicStyleManager();
  final creditManager = CreditManager()..shouldSaveToFile = false;
  final creationsManager = CreationsManager()..shouldSaveToFile = false;
  return NotificationsProvider(
    notifier: manager,
    child: StyleProvider(
      notifier: styleManager,
      child: CreditProvider(
        notifier: creditManager,
        child: FavoritesProvider(
          notifier: favManager,
          child: CreationsProvider(
            notifier: creationsManager,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NotificationsScreen - real feed', () {
    testWidgets('renders backend notifications grouped by recency', (tester) async {
      final manager = await _seededManager([
        _notification(
          id: 'n1',
          type: 'generation',
          title: 'Your image is ready',
          body: 'Styled with Cyberpunk.',
        ),
        _notification(
          id: 'n2',
          title: 'Welcome to StyliAI',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ], 1);

      await tester.pumpWidget(_wrap(
        manager,
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Your image is ready'), findsOneWidget);
      expect(find.text('Welcome to StyliAI'), findsOneWidget);
    });

    testWidgets('shows the empty state for an empty feed', (tester) async {
      final manager = await _seededManager([], 0);

      await tester.pumpWidget(_wrap(
        manager,
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('shows the error state when loading fails', (tester) async {
      final manager = NotificationsManager();
      manager.fetchOverride = () async => throw Exception('network down');
      await manager.fetch();

      await tester.pumpWidget(_wrap(
        manager,
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(find.text('Failed to load notifications'), findsOneWidget);
    });

    testWidgets('tapping an unread notification marks it read and updates the count', (tester) async {
      final manager = await _seededManager([_notification()], 1);
      manager.markReadOverride = (_) async => 0;

      await tester.pumpWidget(_wrap(
        manager,
        const NotificationsScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(manager.unreadCount, 1);
      await tester.tap(find.text('Welcome to StyliAI'));
      await tester.pumpAndSettle();

      expect(manager.notifications.single.isRead, isTrue);
      expect(manager.unreadCount, 0);
    });
  });

  group('NotificationsManager', () {
    test('reverts the optimistic mark-read when the backend call fails', () async {
      final manager = NotificationsManager();
      manager.fetchOverride = () async =>
          (notifications: [_notification()], unreadCount: 1);
      manager.markReadOverride = (_) async => throw Exception('network down');
      await manager.fetch();

      await manager.markRead('n1');

      expect(manager.notifications.single.isRead, isFalse);
      expect(manager.unreadCount, 1);
    });

    test('clear wipes the feed and badge', () async {
      final manager = await _seededManager([_notification()], 1);

      manager.clear();

      expect(manager.notifications, isEmpty);
      expect(manager.unreadCount, 0);
      expect(manager.hasLoaded, isFalse);
    });
  });

  group('ProfileScreen - notifications badge', () {
    testWidgets('shows the unread count and hides it at zero', (tester) async {
      final manager = await _seededManager([_notification()], 3);

      await tester.pumpWidget(_wrap(
        manager,
        const ProfileScreen(isDarkMode: true),
      ));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);

      // Reading everything clears the badge without re-opening the screen.
      manager.fetchOverride = () async => (notifications: <AppNotification>[], unreadCount: 0);
      await manager.fetch();
      await tester.pump();

      expect(find.text('3'), findsNothing);
    });
  });
}
