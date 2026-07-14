// Regression coverage for StyleCard's optional heroTag: a style marked
// Trending is deliberately rendered twice on Home (once in the Trending
// row, once in its own category row) at the same time. Flutter's Hero
// mechanism scans the *outgoing* route for duplicate tags only when a
// transition actually starts (push/pop) - a static build with duplicate
// tags won't trip it, so these tests drive a real Navigator.push to
// reproduce the scan home_screen.dart's card taps trigger for real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/models/style_model.dart';
import 'package:prombt_app/widgets/style_card.dart';

const _trendingStyle = StyleModel(
  id: 'style-1',
  name: 'Trending Style',
  imagePath: 'assets/placeholder.png',
  isTrending: true,
);

// Mirrors Home: two rows both showing the trending style. Tapping the
// first card pushes a details route whose own Hero uses that card's tag -
// exactly like StyleDetailsScreen receiving the tapped card's heroTag.
Widget _homeRoute({required String firstTag, required String secondTag}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: SizedBox(
          height: 250,
          child: Row(
            children: [
              SizedBox(
                width: 135,
                key: const Key('first-card'),
                child: StyleCard(
                  style: _trendingStyle,
                  isDarkMode: true,
                  cardWidth: 135,
                  heroTag: firstTag,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: Hero(tag: firstTag, child: const Text('detail')),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 135,
                child: StyleCard(
                  style: _trendingStyle,
                  isDarkMode: true,
                  cardWidth: 135,
                  heroTag: secondTag,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'tapping into the trending style from Home does not collide on Hero tag with its own category row',
    (tester) async {
      await tester.pumpWidget(_homeRoute(
        firstTag: 'home_Trending Styles_${_trendingStyle.id}',
        secondTag: 'home_Portraits_${_trendingStyle.id}',
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('first-card')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detail'), findsOneWidget);
    },
  );

  testWidgets(
    'sanity check: reusing the same heroTag for both instances does throw on navigation',
    (tester) async {
      await tester.pumpWidget(_homeRoute(
        firstTag: 'duplicate_tag',
        secondTag: 'duplicate_tag',
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('first-card')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNotNull);
    },
  );
}
