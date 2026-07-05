import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/favorites_manager.dart';
import 'data/dynamic_style_manager.dart';
import 'data/credit_manager.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';

const String supabaseUrl = 'https://qsvftsmpqsilmpeyacqn.supabase.co';
const String supabaseAnonKey = 'sb_publishable_fZfVdgp1JtG6F_EXak0xiA_nEMVl0GT';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (with credentials placeholders)
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const PrombtApp());
}

/// Provides [FavoritesManager] to the widget tree via InheritedNotifier.
class FavoritesProvider extends InheritedNotifier<FavoritesManager> {
  const FavoritesProvider({
    super.key,
    required FavoritesManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static FavoritesManager of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<FavoritesProvider>();
    return provider!.notifier!;
  }
}

/// Provides [DynamicStyleManager] to the widget tree via InheritedNotifier.
class StyleProvider extends InheritedNotifier<DynamicStyleManager> {
  const StyleProvider({
    super.key,
    required DynamicStyleManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static DynamicStyleManager of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<StyleProvider>();
    return provider!.notifier!;
  }
}

/// Provides [CreditManager] to the widget tree via InheritedNotifier.
class CreditProvider extends InheritedNotifier<CreditManager> {
  const CreditProvider({
    super.key,
    required CreditManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static CreditManager of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CreditProvider>();
    return provider!.notifier!;
  }
}

class PrombtApp extends StatefulWidget {
  const PrombtApp({super.key});

  @override
  State<PrombtApp> createState() => _PrombtAppState();
}

class _PrombtAppState extends State<PrombtApp> {
  final _favoritesManager = FavoritesManager();
  final _styleManager = DynamicStyleManager();
  final _creditManager = CreditManager();

  @override
  void initState() {
    super.initState();
    _styleManager.init();
    _creditManager.init();
  }

  @override
  void dispose() {
    _favoritesManager.dispose();
    _styleManager.dispose();
    _creditManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StyleProvider(
      notifier: _styleManager,
      child: CreditProvider(
        notifier: _creditManager,
        child: FavoritesProvider(
          notifier: _favoritesManager,
          child: MaterialApp(
            title: 'StyliAI — AI Photo Styles',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const LandingScreen(),
          ),
        ),
      ),
    );
  }
}
