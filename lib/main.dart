import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/favorites_manager.dart';
import 'data/dynamic_style_manager.dart';
import 'data/credit_manager.dart';
import 'data/creations_manager.dart';
import 'data/profile_manager.dart';
import 'data/notifications_manager.dart';
import 'theme/app_theme.dart';
import 'screens/landing_screen.dart';
import 'services/theme_preference_service.dart';
import 'services/haptic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemePreferenceService.load();
  await HapticService.load();

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

  unawaited(MobileAds.instance.initialize());

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

  static FavoritesManager read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<FavoritesProvider>();
    return (element?.widget as FavoritesProvider?)!.notifier!;
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

  static CreationsManager read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<CreationsProvider>();
    return (element?.widget as CreationsProvider?)!.notifier!;
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

  static DynamicStyleManager read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<StyleProvider>();
    return (element?.widget as StyleProvider?)!.notifier!;
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

  static CreditManager read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<CreditProvider>();
    return (element?.widget as CreditProvider?)!.notifier!;
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

  static ProfileManager read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<ProfileProvider>();
    final provider = element?.widget as ProfileProvider?;
    if (provider == null) {
      return ProfileManager();
    }
    return provider.notifier!;
  }
}

/// Provides [NotificationsManager] to the widget tree via InheritedNotifier.
/// Falls back to a fresh manager when no provider is present (widget tests),
/// same as [ProfileProvider].
class NotificationsProvider extends InheritedNotifier<NotificationsManager> {
  const NotificationsProvider({
    super.key,
    required NotificationsManager notifier,
    required super.child,
  }) : super(notifier: notifier);

  static NotificationsManager of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<NotificationsProvider>();
    if (provider == null) {
      return NotificationsManager();
    }
    return provider.notifier!;
  }

  static NotificationsManager read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<NotificationsProvider>();
    final provider = element?.widget as NotificationsProvider?;
    if (provider == null) {
      return NotificationsManager();
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
  final _notificationsManager = NotificationsManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _favoritesManager.init();
      _styleManager.init();
      _creditManager.init();
      _creationsManager.init();
      _profileManager.loadProfile();
      _notificationsManager.init();
      _setHighRefreshRate();
    });
  }

  // Android defaults every app's window to 60Hz regardless of the display's
  // real capability - without this, a 90/120Hz-capable device silently caps
  // Flutter at 60Hz no matter how fast frames actually build/raster. Must run
  // after the first frame: flutter_displaymode's native side requires an
  // Activity to already be attached to the plugin, which isn't the case yet
  // during main() before runApp().
  Future<void> _setHighRefreshRate() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterDisplayMode.setHighRefreshRate();
      } catch (e) {
        debugPrint("⚠️ Failed to set high refresh rate: $e");
      }
    }
  }

  @override
  void dispose() {
    _favoritesManager.dispose();
    _styleManager.dispose();
    _creditManager.dispose();
    _creationsManager.dispose();
    _profileManager.dispose();
    _notificationsManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationsProvider(
      notifier: _notificationsManager,
      child: ProfileProvider(
        notifier: _profileManager,
        child: StyleProvider(
          notifier: _styleManager,
          child: CreditProvider(
            notifier: _creditManager,
            child: FavoritesProvider(
              notifier: _favoritesManager,
              child: CreationsProvider(
                notifier: _creationsManager,
                // Baseline for every pre-auth screen (Landing/Login/Register/
                // etc.), which are always dark, regardless of the user's saved
                // light/dark preference - MainShell overrides this with its
                // own reactive AnnotatedRegion once the user is signed in.
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
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
        ),
      ),
    );
  }
}
