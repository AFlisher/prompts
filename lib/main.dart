import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/favorites_manager.dart';
import 'data/dynamic_style_manager.dart';
import 'data/credit_manager.dart';
import 'data/creations_manager.dart';
import 'data/profile_manager.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';
import 'services/theme_preference_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemePreferenceService.load();

  try {
    // تحميل ملف .env
    await dotenv.load(fileName: ".env");

    // تهيئة Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
      ),
    );

    debugPrint("✅ Supabase Connected");
  } catch (e) {
    debugPrint("❌ Supabase Initialization Error: $e");
  }

  await SystemChrome.setPreferredOrientations([
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

/// Provides [CreationsManager] to the widget tree via InheritedNotifier.
class CreationsProvider extends InheritedNotifier<CreationsManager> {
  const CreationsProvider({
    super.key,
    required CreationsManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static CreationsManager of(BuildContext context) {
    final provider =
    context.dependOnInheritedWidgetOfExactType<CreationsProvider>();
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

/// Provides [ProfileManager] to the widget tree via InheritedNotifier.
class ProfileProvider extends InheritedNotifier<ProfileManager> {
  const ProfileProvider({
    super.key,
    required ProfileManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ProfileManager of(BuildContext context) {
    final provider =
    context.dependOnInheritedWidgetOfExactType<ProfileProvider>();
    if (provider == null) {
      return ProfileManager();
    }
    return provider.notifier!;
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
  final _creationsManager = CreationsManager();
  final _profileManager = ProfileManager();

  @override
  void initState() {
    super.initState();
    _styleManager.init();
    _creditManager.init();
    _creationsManager.init();
  }

  @override
  void dispose() {
    _favoritesManager.dispose();
    _styleManager.dispose();
    _creditManager.dispose();
    _creationsManager.dispose();
    _profileManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileProvider(
      notifier: _profileManager,
      child: StyleProvider(
        notifier: _styleManager,
        child: CreditProvider(
          notifier: _creditManager,
          child: FavoritesProvider(
            notifier: _favoritesManager,
            child: CreationsProvider(
              notifier: _creationsManager,
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
        ),
      ),
    );
  }
}