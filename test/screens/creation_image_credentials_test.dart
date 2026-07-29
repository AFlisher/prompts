// test/screens/creation_image_credentials_test.dart
//
// SEC-8.1B-2 regression: every surface that renders a creation's
// full-resolution original must route it through AuthorizedImage.
//
// This is the mistake that actually happened. ProgressiveNetworkImage accepted
// httpHeaders and forwarded them correctly; the grid card supplied them; the
// detail card and the full-screen viewer did not. Once delivery moved behind
// an authenticated endpoint, those two 401'd and silently fell back to the
// thumbnail forever.
//
// The assertions here are structural on purpose. Resolving real credentials
// means calling AuthService, which never completes under `flutter test`, so
// these tests use today's public storage URLs - which also makes them the
// proof that public and catalog images are unaffected, since AuthorizedImage
// short-circuits synchronously to no headers for anything off-origin.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/creations_manager.dart';
import 'package:prombt_app/screens/creations_screen.dart';
import 'package:prombt_app/screens/image_preview_screen.dart';
import 'package:prombt_app/utils/image_delivery.dart';
import 'package:prombt_app/widgets/progressive_network_image.dart';
import '../helpers/test_helpers.dart';

void main() {
  const publicOriginal =
      'https://proj.supabase.co/storage/v1/object/public/creations/original/abc.webp';
  const publicThumb =
      'https://proj.supabase.co/storage/v1/object/public/creations/thumbs/abc.webp';

  /// The AuthorizedImage wrapping the progressive image, if there is one.
  Finder authorizedWrapper() => find.ancestor(
        of: find.byType(ProgressiveNetworkImage),
        matching: find.byType(AuthorizedImage),
      );

  group('ImagePreviewScreen - the full-screen viewer', () {
    testWidgets('routes the original through AuthorizedImage', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: publicOriginal,
          thumbnailPath: publicThumb,
          title: 'Comic Pop Art',
          creationId: 'c-1',
        ),
      ));
      await tester.pump();

      expect(authorizedWrapper(), findsOneWidget,
          reason: 'without this wrapper the original 401s and the viewer is '
              'stuck on the thumbnail');
    });

    testWidgets('decides credentials on the original URL, not the thumbnail',
        (tester) async {
      // Both share an origin today, so this is not currently load-bearing for
      // correctness - but the URL being authorized must be the URL being
      // fetched, or the decision is made about the wrong request.
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: publicOriginal,
          thumbnailPath: publicThumb,
          title: 'Comic Pop Art',
          creationId: 'c-1',
        ),
      ));
      await tester.pump();

      expect(tester.widget<AuthorizedImage>(authorizedWrapper()).url, publicOriginal);
    });

    testWidgets('keeps the creation-scoped cache keys intact', (tester) async {
      // The cache keys are what let the bytes survive a URL change. The fix
      // must not have disturbed them.
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: publicOriginal,
          thumbnailPath: publicThumb,
          title: 'Comic Pop Art',
          creationId: 'c-1',
        ),
      ));
      await tester.pump();

      final progressive =
          tester.widget<ProgressiveNetworkImage>(find.byType(ProgressiveNetworkImage));
      expect(progressive.thumbnailCacheKey, creationCacheKey('c-1', thumbnail: true));
      expect(progressive.originalCacheKey, creationCacheKey('c-1', thumbnail: false));
    });

    testWidgets('attaches nothing to a public storage URL', (tester) async {
      // Today's behaviour, unchanged: off-origin gets no credentials at all.
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: publicOriginal,
          thumbnailPath: publicThumb,
          title: 'Comic Pop Art',
          creationId: 'c-1',
        ),
      ));
      await tester.pump();

      final progressive =
          tester.widget<ProgressiveNetworkImage>(find.byType(ProgressiveNetworkImage));
      expect(progressive.httpHeaders, isNull);
    });

    testWidgets('still renders a bundled asset preview', (tester) async {
      // A style asset has no separate thumbnail and is not ours - the wrapper
      // must not gate it behind anything.
      await tester.pumpWidget(const MaterialApp(
        home: ImagePreviewScreen(
          assetPath: 'assets/images/style_arabic.jpg',
          title: 'Arabic Style',
        ),
      ));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Arabic Style'), findsOneWidget);
    });
  });

  group('MyCreationsScreen - the detail card', () {
    Future<void> openDetailSheet(WidgetTester tester) async {
      final manager = CreationsManager()..shouldSaveToFile = false;
      manager.shouldSyncWithBackend = false;
      await manager.addCreation(CreationItem(
        id: 'c-1',
        styleId: 'comic',
        styleName: 'Comic Pop Art',
        imagePath: publicOriginal,
        thumbnailUrl: publicThumb,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
        creationsManager: manager,
      ));
      await tester.pump();

      await tester.tap(find.text('Comic Pop Art'));
      // Bounded pumps rather than pumpAndSettle: the network placeholder is a
      // Shimmer, which animates forever, so nothing here ever settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('routes the original through AuthorizedImage', (tester) async {
      await openDetailSheet(tester);

      expect(authorizedWrapper(), findsOneWidget);
      expect(tester.widget<AuthorizedImage>(authorizedWrapper()).url, publicOriginal);
    });

    testWidgets('keeps the creation-scoped cache keys intact', (tester) async {
      await openDetailSheet(tester);

      final progressive =
          tester.widget<ProgressiveNetworkImage>(find.byType(ProgressiveNetworkImage));
      expect(progressive.thumbnailCacheKey, creationCacheKey('c-1', thumbnail: true));
      expect(progressive.originalCacheKey, creationCacheKey('c-1', thumbnail: false));
    });

    testWidgets('keeps the grid card authorized too', (tester) async {
      // The grid card was the one surface that already worked. It must stay
      // that way - it is why thumbnails rendered at all while this was broken.
      final manager = CreationsManager()..shouldSaveToFile = false;
      manager.shouldSyncWithBackend = false;
      await manager.addCreation(CreationItem(
        id: 'c-1',
        styleId: 'comic',
        styleName: 'Comic Pop Art',
        imagePath: publicOriginal,
        thumbnailUrl: publicThumb,
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(wrapWithProviders(
        const MyCreationsScreen(isDarkMode: true),
        creationsManager: manager,
      ));
      await tester.pump();

      expect(find.byType(AuthorizedImage), findsOneWidget);
      expect(tester.widget<AuthorizedImage>(find.byType(AuthorizedImage)).url,
          publicThumb);
    });
  });
}
