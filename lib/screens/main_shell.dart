import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'creations_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isDarkMode = false;

  void _onNavigate(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          isDarkMode: _isDarkMode,
          onToggleDarkMode: () => setState(() => _isDarkMode = !_isDarkMode),
        );
      case 1:
        return MyCreationsScreen(isDarkMode: _isDarkMode);
      case 2:
        return FavoritesScreen(isDarkMode: _isDarkMode);
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
    final bgColor = _isDarkMode ? AppTheme.black : AppTheme.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedSwitcher(
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
          key: ValueKey<int>(_currentIndex),
          child: _buildScreen(),
        ),
      ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        isDarkMode: _isDarkMode,
        onTap: _onNavigate,
      ),
    );
  }
}

class _GlassNavBar extends StatefulWidget {
  final int currentIndex;
  final bool isDarkMode;
  final ValueChanged<int> onTap;

  const _GlassNavBar({
    required this.currentIndex,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _indicatorAnim;

  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _indicatorAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.value = 1;
  }

  @override
  void didUpdateWidget(_GlassNavBar old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex) {
      _previousIndex = old.currentIndex;
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
          child: Container(
            height: 72,
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
                AnimatedBuilder(
                  animation: _indicatorAnim,
                  builder: (context, child) {
                    final fromX = _indicatorX(_previousIndex);
                    final toX = _indicatorX(widget.currentIndex);
                    final x = fromX + (toX - fromX) * _indicatorAnim.value;
                    return Padding(
                      padding: EdgeInsets.only(left: x),
                      child: Container(
                        width: 64,
                        height: 36,
                        margin: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  },
                ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _indicatorX(int index) {
    final totalWidth = MediaQuery.of(context).size.width - 32;
    final tabWidth = totalWidth / 4;
    return tabWidth * index + (tabWidth - 64) / 2;
  }

  IconData _iconFor(int index, {required bool selected}) {
    switch (index) {
      case 0:
        return selected ? Icons.home_rounded : Icons.home_outlined;
      case 1:
        return selected
            ? Icons.auto_awesome
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
