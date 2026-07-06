import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/data/favorites_manager.dart';
import 'package:prombt_app/data/dynamic_style_manager.dart';
import 'package:prombt_app/data/credit_manager.dart';
import 'package:prombt_app/data/creations_manager.dart';

// ─── Test Helpers ────────────────────────────────────────────────────────────
Widget wrapWithApp(Widget widget) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: widget,
  );
}

Widget wrapWithProviders(Widget widget, {CreationsManager? creationsManager}) {
  final favManager    = FavoritesManager();
  final styleManager  = DynamicStyleManager();
  final creditManager = CreditManager()..shouldSaveToFile = false;
  final creations = creationsManager ?? (CreationsManager()..shouldSaveToFile = false);
  return StyleProvider(
    notifier: styleManager,
    child: CreditProvider(
      notifier: creditManager,
      child: FavoritesProvider(
        notifier: favManager,
        child: CreationsProvider(
          notifier: creations,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: widget,
          ),
        ),
      ),
    ),
  );
}
