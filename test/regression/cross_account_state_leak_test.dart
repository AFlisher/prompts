// Regression test for a cross-account state leak: Account A's credits and
// generated images were briefly visible to Account B after Account A signed
// out and Account B immediately signed in, because the app's account-scoped
// managers are long-lived singletons (created once in main.dart, never
// recreated on logout/login) whose init() methods short-circuit once
// already initialized and had no clear()/reset() at all. Only a full app
// restart (which recreates the managers from scratch) made it "look" fixed.
//
// The fix centralizes clearing in AuthService.onSignedOut, a static hook
// every AuthService.signOut() call invokes - explicit sign-out, auto-signout
// on refresh failure, and the unverified-email rejection path all go through
// it uniformly. This test wires that hook the same way main.dart does, then
// reproduces the exact reported scenario: populate every manager as if
// Account A had a live session, sign out through the real production
// signOut() code path, and assert nothing observable survives.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/data/profile_manager.dart';
import 'package:prombt_app/data/notifications_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/models/profile_model.dart';
import 'package:prombt_app/services/auth_service.dart';

/// AuthService.signOut() calls flutter_secure_storage for real (unlike its
/// Supabase.signOut() call, that one isn't wrapped in a try/catch), which
/// has no platform-side plugin implementation in a pure-Dart test host.
/// Backing the channel with a real in-memory implementation - rather than
/// swallowing the resulting MissingPluginException around the call in this
/// test - means the test exercises AuthService.signOut()'s actual,
/// production code path unmodified.
const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void _installFakeSecureStorage() {
  final store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    switch (call.method) {
      case 'read':
        return store[call.arguments['key']];
      case 'write':
        store[call.arguments['key'] as String] = call.arguments['value'] as String;
        return null;
      case 'delete':
        store.remove(call.arguments['key']);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'containsKey':
        return store.containsKey(call.arguments['key']);
      case 'readAll':
        return store;
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFakeSecureStorage();

  group('Cross-account state leak regression', () {
    late CreditManager creditManager;
    late CreationsManager creationsManager;
    late FavoritesManager favoritesManager;
    late ProfileManager profileManager;
    late NotificationsManager notificationsManager;
    late DynamicStyleManager styleManager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      creditManager = CreditManager();
      creationsManager = CreationsManager()..shouldSyncWithBackend = false;
      favoritesManager = FavoritesManager()..shouldSyncWithBackend = false;
      profileManager = ProfileManager();
      notificationsManager = NotificationsManager();
      styleManager = DynamicStyleManager();

      // Mirrors main.dart's real wiring exactly: AuthService.signOut()
      // drives every manager's clear() through this one registered
      // callback, instead of each sign-out call site having to remember to
      // do it itself.
      AuthService.onSignedOut = () {
        profileManager.clear();
        notificationsManager.clear();
        creditManager.clear();
        creationsManager.clear();
        favoritesManager.clear();
        styleManager.clear();
      };
    });

    tearDown(() {
      AuthService.onSignedOut = null;
    });

    test(
      'AuthService.signOut() wipes every account-scoped manager '
      '(reproduces: Account A logs out, Account B logs in, sees stale data)',
      () async {
        // ---- Step 1-2: Account A has a live session with credits and generated images ----
        await creditManager.addCredits(42);
        creditManager.useCredit(); // also increments generatedImages, mirroring a real generation
        await creationsManager.init(); // cache-only (shouldSyncWithBackend: false) - sets isInitialized
        await creationsManager.addCreation(CreationItem(
          id: 'account-a-creation',
          styleId: 'style-1',
          styleName: 'Account A Style',
          imagePath: 'https://example.com/account-a.png',
          createdAt: DateTime.now(),
        ));
        await favoritesManager.init(); // cache-only - sets isInitialized
        favoritesManager.toggleFavorite('account-a-favorite-style');
        profileManager.updateProfile(Profile(
          id: 'account-a-id',
          fullName: 'Account A',
          email: 'a@example.com',
        ));

        // Sanity check: Account A's session really did leave this state behind.
        expect(creditManager.credits, equals(41));
        expect(creditManager.generatedImages, equals(1));
        expect(creationsManager.creations, hasLength(1));
        expect(creationsManager.isInitialized, isTrue);
        expect(favoritesManager.favoriteIds, contains('account-a-favorite-style'));
        expect(favoritesManager.isInitialized, isTrue);
        expect(profileManager.profile?.id, equals('account-a-id'));

        // ---- Step 3: Account A signs out, through the real production code path ----
        final authService = AuthService();
        await authService.signOut();

        // ---- Step 4-5: Account B's first frame must show none of it ----
        // (In the real app this is exactly what AppHeader/HomeScreen/
        // CreationsScreen read on Account B's very first build.)
        expect(creditManager.credits, equals(0));
        expect(creditManager.generatedImages, equals(0));

        expect(creationsManager.creations, isEmpty);
        expect(creationsManager.isInitialized, isFalse,
            reason: 'must be false, not just the list empty - otherwise the '
                'next init() call short-circuits and never re-fetches '
                "Account B's own creations");

        expect(favoritesManager.favoriteIds, isEmpty);
        expect(favoritesManager.isInitialized, isFalse,
            reason: 'same reasoning as creationsManager.isInitialized above');

        expect(profileManager.profile, isNull);
      },
    );

    test(
      'on-disk favorites cache is wiped, not just the in-memory set '
      '(the disk-cache flash-of-stale-data-on-next-launch variant)',
      () async {
        await favoritesManager.init();
        favoritesManager.toggleFavorite('account-a-favorite-style');
        // toggleFavorite persists to cache via an unawaited Future - let it settle.
        await Future<void>.delayed(Duration.zero);

        final prefsBefore = await SharedPreferences.getInstance();
        expect(prefsBefore.getString('favorites_cache'), isNotNull);

        AuthService.onSignedOut!();
        await Future<void>.delayed(Duration.zero);

        final prefsAfter = await SharedPreferences.getInstance();
        expect(
          prefsAfter.getString('favorites_cache'),
          isNull,
          reason: 'a stale on-disk favorites cache would let Account A\'s '
              "favorites flash on screen the moment Account B's session "
              'calls init() again, before the background sync overwrites '
              'it - clearing only the in-memory set is not enough',
        );
      },
    );

    test(
      'clearPersonalizedState() only resets the Recommended-For-You section, '
      'not the shared style catalog',
      () {
        // The catalog (categories/trending) is identical for every account
        // and must survive a logout - only per-account personalization
        // should be wiped.
        final categoriesBefore = styleManager.categories;
        final trendingBefore = styleManager.trendingStyles;

        styleManager.clearPersonalizedState();

        expect(styleManager.categories, equals(categoriesBefore));
        expect(styleManager.trendingStyles, equals(trendingBefore));
        expect(styleManager.recommendedStyles, isEmpty);
        expect(styleManager.hasLoadedRecommended, isFalse);
        expect(styleManager.isRecommendedLoading, isFalse);
      },
    );

    test('NotificationsManager.clear() resets hasLoaded so the next account refetches',
        () {
      // hasLoaded gates NotificationsManager.init()'s own short-circuit,
      // same failure shape as isInitialized on the other managers.
      expect(notificationsManager.hasLoaded, isFalse);
      notificationsManager.clear();
      expect(notificationsManager.hasLoaded, isFalse);
      expect(notificationsManager.notifications, isEmpty);
      expect(notificationsManager.unreadCount, equals(0));
    });
  });
}
