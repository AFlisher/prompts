// test/widgets/progressive_network_image_auth_test.dart
//
// SEC-8.1B-2 regression: the full-screen viewer never upgraded past the
// thumbnail.
//
// ProgressiveNetworkImage gained httpHeaders support in step 2 and forwarded it
// correctly, but no caller ever passed it. Step 3 then made creation URLs
// require authentication, so the "original" layer requested
// /api/creations/<id>/image with no Authorization header and got a 401. That
// routed to errorWidget, which meant imageBuilder never ran - and imageBuilder
// is the only thing that starts the hand-off away from the thumbnail. The
// thumbnail layer therefore stayed in the tree forever, at 320x400, upscaled
// to fill the viewer.
//
// These tests pin both halves of that contract: credentials reach both layers,
// and a successful original actually evicts the thumbnail.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prombt_app/widgets/progressive_network_image.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  const thumbKey = 'creation:c-1:thumb';
  const originalKey = 'creation:c-1:original';

  Iterable<CachedNetworkImage> layers(WidgetTester tester) =>
      tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));

  CachedNetworkImage layerWithKey(WidgetTester tester, String key) =>
      layers(tester).firstWhere((w) => w.cacheKey == key);

  bool hasLayerWithKey(WidgetTester tester, String key) =>
      layers(tester).any((w) => w.cacheKey == key);

  Widget subject({Map<String, String>? httpHeaders}) => ProgressiveNetworkImage(
        thumbnailUrl: 'https://example.com/thumb.webp',
        originalUrl: 'https://example.com/original.webp',
        thumbnailCacheKey: thumbKey,
        originalCacheKey: originalKey,
        httpHeaders: httpHeaders,
      );

  group('ProgressiveNetworkImage - credential passthrough', () {
    testWidgets('forwards credentials to both the thumbnail and original layers',
        (tester) async {
      // Both layers are fetched from the same authenticated origin, so both
      // need the header. Authenticating only the original would leave the
      // thumbnail broken on a cold cache.
      const headers = {'Authorization': 'Bearer token-abc'};

      await tester.pumpWidget(wrap(subject(httpHeaders: headers)));

      expect(layers(tester).length, 2);
      for (final layer in layers(tester)) {
        expect(layer.httpHeaders, headers,
            reason: 'every layer must carry the credentials it was given');
        expect(layer.httpHeaders!.containsKey('Authorization'), isTrue);
      }
    });

    testWidgets('forwards credentials when there is no distinct thumbnail',
        (tester) async {
      // The single-layer branch: a creation with no thumbnail row still has to
      // authenticate its original.
      const headers = {'Authorization': 'Bearer token-abc'};

      await tester.pumpWidget(wrap(const ProgressiveNetworkImage(
        thumbnailUrl: '',
        originalUrl: 'https://example.com/original.webp',
        originalCacheKey: originalKey,
        httpHeaders: headers,
      )));

      final only = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(only.httpHeaders, headers);
    });

    testWidgets('sends no headers when given none, so catalog images are unchanged',
        (tester) async {
      // Style/catalog images are public and off-origin. imageAuthHeaders
      // returns nothing for them, and nothing is exactly what must reach the
      // request - the access token must never leave our own origin.
      await tester.pumpWidget(wrap(subject()));

      expect(layers(tester).length, 2);
      for (final layer in layers(tester)) {
        expect(layer.httpHeaders, isNull);
      }
    });
  });

  group('ProgressiveNetworkImage - the thumbnail to original swap', () {
    testWidgets('drops the thumbnail once the original has a frame to paint',
        (tester) async {
      await tester.pumpWidget(wrap(subject()));

      // Both layers start in the tree, thumbnail underneath.
      expect(hasLayerWithKey(tester, thumbKey), isTrue);
      expect(hasLayerWithKey(tester, originalKey), isTrue);

      // Stand in for CachedNetworkImage's own success path: imageBuilder is
      // what it calls once the original has decoded, and is the only trigger
      // for the hand-off. Invoking it directly exercises the real state
      // machine without needing a live image fetch.
      final original = layerWithKey(tester, originalKey);
      expect(original.imageBuilder, isNotNull,
          reason: 'the swap is gated behind the original layer imageBuilder');
      original.imageBuilder!(
        tester.element(find.byType(ProgressiveNetworkImage)),
        MemoryImage(Uint8List(0)),
      );

      // The thumbnail is held for exactly the crossfade, then removed.
      await tester.pump(const Duration(milliseconds: 300));

      expect(hasLayerWithKey(tester, thumbKey), isFalse,
          reason: 'the thumbnail must leave the tree, not just be painted over');
      expect(hasLayerWithKey(tester, originalKey), isTrue,
          reason: 'the original is what the viewer shows from here on');
    });

    testWidgets('keeps the thumbnail while the original has produced no frame',
        (tester) async {
      // This is the exact shape of the regression, and why it presented as a
      // permanently soft image rather than a broken one: when the original
      // fails (a 401 on an uncredentialed delivery URL) the thumbnail stays,
      // so the viewer looks populated while showing 320x400 of detail.
      await tester.pumpWidget(wrap(subject()));

      await tester.pump(const Duration(seconds: 2));

      expect(hasLayerWithKey(tester, thumbKey), isTrue,
          reason: 'a failed original must fall back to the thumbnail, not blank');
    });

    testWidgets('shows the thumbnail again when a different original is supplied',
        (tester) async {
      await tester.pumpWidget(wrap(subject()));

      final original = layerWithKey(tester, originalKey);
      original.imageBuilder!(
        tester.element(find.byType(ProgressiveNetworkImage)),
        MemoryImage(Uint8List(0)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(hasLayerWithKey(tester, thumbKey), isFalse);

      // Re-pointing at another creation must restart the progression rather
      // than leaving the previous original's state behind.
      await tester.pumpWidget(wrap(const ProgressiveNetworkImage(
        thumbnailUrl: 'https://example.com/thumb-2.webp',
        originalUrl: 'https://example.com/original-2.webp',
        thumbnailCacheKey: 'creation:c-2:thumb',
        originalCacheKey: 'creation:c-2:original',
      )));

      expect(hasLayerWithKey(tester, 'creation:c-2:thumb'), isTrue);
    });
  });
}
