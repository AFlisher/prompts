import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_nav_bar_metrics.dart';
import '../main.dart';
import 'home_screen.dart';
import 'creations_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/theme_preference_service.dart';
import '../services/haptic_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _isDarkMode = ThemePreferenceService.isDarkMode;

  void _toggleDarkMode() {
    HapticService.selection();
    setState(() => _isDarkMode = !_isDarkMode);
    ThemePreferenceService.setIsDarkMode(_isDarkMode);
  }

  // Isolated from this State's own setState so toggling it only rebuilds
  // the nav bar (via the ValueListenableBuilder in build()) - never the
  // active tab's screen.
  final ValueNotifier<bool> _navCollapsed = ValueNotifier<bool>(false);

  // Hysteresis: only flip _navCollapsed once the user has scrolled a
  // meaningful distance in one direction, so a handful of stray pixels
  // (or the natural jitter at the start of a drag) can't toggle it.
  double _scrollAccumulator = 0;
  double? _lastPixels;
  static const double _collapseThreshold = 24.0;

  bool _handleScrollNotification(ScrollNotification notification) {
    // depth == 0 means this notification comes from the tab's own primary
    // scrollable, not a nested one (e.g. Home's horizontal style rows) -
    // bubbling through Scrollable ancestors increments depth, so nested
    // scroll views never trigger this.
    if (notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      final lastPixels = _lastPixels;
      _lastPixels = pixels;
      if (lastPixels == null) return false;

      // Compute delta from the absolute scroll offset ourselves - pixels
      // increasing unambiguously means the content is advancing (scrolling
      // down) regardless of how scrollDelta's own sign is reported.
      final delta = pixels - lastPixels;
      if (delta == 0) return false;

      // A reversal discards whatever progress had built up toward the old
      // direction's threshold, rather than letting it partially cancel out.
      if (_scrollAccumulator != 0 && (delta > 0) != (_scrollAccumulator > 0)) {
        _scrollAccumulator = 0;
      }
      _scrollAccumulator += delta;

      if (_scrollAccumulator > _collapseThreshold) {
        _navCollapsed.value = true;
        _scrollAccumulator = 0;
      } else if (_scrollAccumulator < -_collapseThreshold) {
        _navCollapsed.value = false;
        _scrollAccumulator = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _scrollAccumulator = 0;
      _lastPixels = null;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          CreationsProvider.read(context).setTab(0);
        } catch (e) {
          debugPrint("Error resetting creations tab on MainShell init: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    _navCollapsed.dispose();
    super.dispose();
  }

  Widget _buildScreen(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return HomeScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: _toggleDarkMode,
        );
      case 1:
        return MyCreationsScreen(isDarkMode: _isDarkMode);
      case 2:
        return FavoritesScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: _toggleDarkMode,
        );
      case 3:
        return ProfileScreen(isDarkMode: _isDarkMode);
      default:
        return HomeScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: _toggleDarkMode,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    if (authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppTheme.black,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.accentPurple),
          ),
        ),
      );
    }

    final bgColor = _isDarkMode ? AppTheme.black : AppTheme.lightBackground;
    final creationsManager = CreationsProvider.of(context);
    final currentIndex = creationsManager.currentTab;

    // AnnotatedRegion (not a one-off SystemChrome.setSystemUIOverlayStyle
    // call) because Flutter re-asserts it on every relevant frame - a plain
    // imperative call made once at app startup, before the first frame
    // exists, was found to be silently dropped or overridden by Android on
    // cold start (confirmed on-device: worked after toggling mid-session,
    // failed on a fresh launch already saved in Light Mode). This is
    // immune to that race and self-heals if the OS resets system UI on
    // resume.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        // No bottomNavigationBar slot: Scaffold wraps that slot in its own
        // Material surface, which paints an opaque rectangle behind whatever
        // widget is given to it - exactly the "rectangle behind the glass
        // bar" this was meant to avoid. A plain Stack overlay has no such
        // surface, so only the nav bar's own rounded shape is ever painted.
        //
        // Deliberately NOT inflating the ambient MediaQuery bottom padding
        // here: every tab screen's own SafeArea would turn that into a
        // permanent layout shrink (visible at every scroll position, not just
        // at the end of the list), which just reproduces a flat, static area
        // behind the glass bar - the same "rectangle" look this exists to
        // avoid. Bottom clearance for each screen's last item is instead
        // added as trailing padding on that screen's own scrollable via
        // FloatingNavBarMetrics.scrollClearance, so it only appears once
        // real content has actually been scrolled past.
        body: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(currentIndex),
                    child: _buildScreen(currentIndex),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _navCollapsed,
                builder: (context, collapsed, _) {
                  return _GlassNavBar(
                    currentIndex: currentIndex,
                    isDarkMode: _isDarkMode,
                    collapsed: collapsed,
                    onTap: (index) {
                      HapticService.light();
                      creationsManager.setTab(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatefulWidget {
  final int currentIndex;
  final bool isDarkMode;
  final bool collapsed;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.isDarkMode,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar> {
  static const _collapseDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final indices = [0, 1, 2, 3];
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset + FloatingNavBarMetrics.floatingMargin,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            inner: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.08),
              BlendMode.overlay,
            ),
          ),
          child: AnimatedContainer(
            duration: _collapseDuration,
            curve: Curves.easeInOut,
            height: widget.collapsed
                ? FloatingNavBarMetrics.collapsedHeight
                : FloatingNavBarMetrics.expandedHeight,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.65),
              border: Border(
                top: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    for (final i in indices)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(i),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _NavIcon(
                                  icon: _iconFor(i, selected: widget.currentIndex == i),
                                  isSelected: widget.currentIndex == i,
                                  isDarkMode: widget.isDarkMode,
                                ),
                                AnimatedSize(
                                  duration: _collapseDuration,
                                  curve: Curves.easeInOut,
                                  child: SizedBox(
                                    height: widget.collapsed ? 0 : null,
                                    child: AnimatedOpacity(
                                      duration: _collapseDuration,
                                      opacity: widget.collapsed ? 0 : 1,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            _labelFor(i),
                                            style: TextStyle(
                                              color: widget.currentIndex == i
                                                  ? AppTheme.accentPurple
                                                  : (widget.isDarkMode
                                                      ? AppTheme.mediumGray
                                                      : Colors.grey[500]),
                                              fontSize: 11,
                                              fontWeight: widget.currentIndex == i
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(int index, {required bool selected}) {
    switch (index) {
      case 0:
        return selected ? Icons.home_rounded : Icons.home_outlined;
      case 1:
        return selected
            ? Icons.auto_awesome_rounded
            : Icons.auto_awesome_outlined;
      case 2:
        return selected
            ? Icons.favorite_rounded
            : Icons.favorite_outline_rounded;
      case 3:
        return selected
            ? Icons.person_rounded
            : Icons.person_outline_rounded;
      default:
        return Icons.home_outlined;
    }
  }

  String _labelFor(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Creations';
      case 2:
        return 'Favorites';
      case 3:
        return 'Profile';
      default:
        return '';
    }
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final bool isDarkMode;

  const _NavIcon({
    required this.icon,
    required this.isSelected,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: isSelected ? 28 : 24,
      height: isSelected ? 28 : 24,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.accentPurple.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: isSelected
            ? AppTheme.accentPurple
            : (isDarkMode ? AppTheme.mediumGray : Colors.grey[500]),
        size: isSelected ? 20 : 22,
      ),
    );
  }
}
