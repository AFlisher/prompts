import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'home_screen.dart';
import 'creations_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _isDarkMode = false;
  bool _navCollapsed = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    // depth == 0 means this notification comes from the tab's own primary
    // scrollable, not a nested one (e.g. Home's horizontal style rows) -
    // bubbling through Scrollable ancestors increments depth, so nested
    // scroll views never trigger this.
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.reverse && !_navCollapsed) {
        setState(() => _navCollapsed = true);
      } else if (direction == ScrollDirection.forward && _navCollapsed) {
        setState(() => _navCollapsed = false);
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          CreationsProvider.of(context).setTab(0);
        } catch (e) {
          debugPrint("Error resetting creations tab on MainShell init: $e");
        }
      }
    });
  }

  Widget _buildScreen(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return HomeScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: () => setState(() => _isDarkMode = !_isDarkMode),
        );
      case 1:
        return MyCreationsScreen(isDarkMode: _isDarkMode);
      case 2:
        return FavoritesScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: () => setState(() => _isDarkMode = !_isDarkMode),
        );
      case 3:
        return ProfileScreen(isDarkMode: _isDarkMode);
      default:
        return HomeScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: () => setState(() => _isDarkMode = !_isDarkMode),
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
      return const Scaffold(
        backgroundColor: AppTheme.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentPurple),
        ),
      );
    }

    final bgColor = _isDarkMode ? AppTheme.black : AppTheme.white;
    final creationsManager = CreationsProvider.of(context);
    final currentIndex = creationsManager.currentTab;

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
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
      bottomNavigationBar: _GlassNavBar(
        currentIndex: currentIndex,
        isDarkMode: _isDarkMode,
        collapsed: _navCollapsed,
        onTap: (index) {
          HapticFeedback.lightImpact();
          creationsManager.setTab(index);
        },
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 8),
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
            height: widget.collapsed ? 56 : 72,
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
