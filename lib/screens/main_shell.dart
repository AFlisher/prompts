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
          onNavigate: _onNavigate,
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
          onNavigate: _onNavigate,
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
    );
  }
}
