// test/widgets/progressive_network_image_decode_size_test.dart
//
// Bottleneck B1 from the image performance audit: ProgressiveNetworkImage's
// "original" layer always decoded at native resolution, even inside fixed-
// size, non-zoomable boxes (StyleDetailsScreen's hero card, UploadScreen's
// result card, Creations' detail sheet). The fix adds optional
// memCacheWidth/memCacheHeight passthrough - this test locks in that the
// values actually reach the underlying CachedNetworkImage (and the
// thumbnail's own buildStyleImage layer), and that omitting them (the
// zoomable-viewer case: ImagePreviewScreen, FullScreenImageViewer) leaves
// decoding unbounded exactly as before.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prombt_app/widgets/progressive_network_image.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ProgressiveNetworkImage - decode size passthrough', () {
    testWidgets(
      'passes memCacheWidth/memCacheHeight through to the original CachedNetworkImage layer',
      (tester) async {
        await tester.pumpWidget(wrap(
          const ProgressiveNetworkImage(
            thumbnailUrl: 'https://example.com/thumb.jpg',
            originalUrl: 'https://example.com/original.jpg',
            memCacheWidth: 300,
            memCacheHeight: 400,
          ),
        ));

        final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
        // Base (thumbnail, via buildStyleImage) + top (original) layers.
        expect(images.length, 2);
        for (final image in images) {
          expect(image.memCacheWidth, 300,
              reason: 'both layers must decode at the same bounded size');
          expect(image.memCacheHeight, 400);
        }
      },
    );

    testWidgets(
      'leaves decoding unbounded when memCacheWidth/memCacheHeight are omitted '
      '(the zoomable-viewer case: ImagePreviewScreen, FullScreenImageViewer)',
      (tester) async {
        await tester.pumpWidget(wrap(
          const ProgressiveNetworkImage(
            thumbnailUrl: 'https://example.com/thumb.jpg',
            originalUrl: 'https://example.com/original.jpg',
          ),
        ));

        final images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(images.length, 2);
        for (final image in images) {
          expect(image.memCacheWidth, isNull,
              reason: 'zoomable viewers must keep decoding at native resolution');
          expect(image.memCacheHeight, isNull);
        }
      },
    );

    testWidgets(
      'renders the original directly (no distinct thumbnail) with bounded size when provided',
      (tester) async {
        await tester.pumpWidget(wrap(
          const ProgressiveNetworkImage(
            thumbnailUrl: '',
            originalUrl: 'https://example.com/original.jpg',
            memCacheWidth: 150,
            memCacheHeight: 200,
          ),
        ));

        final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(image.memCacheWidth, 150);
        expect(image.memCacheHeight, 200);
      },
    );
  });
}
