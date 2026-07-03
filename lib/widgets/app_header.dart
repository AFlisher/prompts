import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final ValueChanged<String>? onMenuSelected;

  const AppHeader({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    this.onMenuSelected,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _isMenuOpen = false;

  void _toggleMenu() {
    HapticFeedback.selectionClick();
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  void _selectMenu(String value) {
    setState(() => _isMenuOpen = false);
    widget.onMenuSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? AppTheme.white : AppTheme.black;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            SizedBox(
              width: 66,
              height: 56,
              child: CustomPaint(
                painter: _LogoPainter(color: textColor),
              ),
            ),
            const Spacer(),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppTheme.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleMenu,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          _isMenuOpen
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.menu_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Menu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 17),
                  GestureDetector(
                    onTap: widget.onToggleDarkMode,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      widget.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 36,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 48,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _isMenuOpen
                ? _HeaderMenu(
                    key: const ValueKey('open-menu'),
                    onSelected: _selectMenu,
                  )
                : const SizedBox.shrink(key: ValueKey('closed-menu')),
          ),
        ),
      ],
    );
  }
}

class _HeaderMenu extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _HeaderMenu({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const items = ['Saved', 'Home', 'Styles', 'Mine'];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 192,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppTheme.black,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              GestureDetector(
                onTap: () => onSelected(item),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: double.infinity,
                  height: 22,
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final aPath = Path()
      ..moveTo(size.width * 0.42, size.height * 0.18)
      ..lineTo(size.width * 0.58, size.height * 0.14)
      ..lineTo(size.width * 0.74, size.height * 0.8)
      ..lineTo(size.width * 0.62, size.height * 0.84)
      ..lineTo(size.width * 0.57, size.height * 0.62)
      ..lineTo(size.width * 0.38, size.height * 0.68)
      ..lineTo(size.width * 0.28, size.height * 0.88)
      ..lineTo(size.width * 0.14, size.height * 0.82)
      ..close();

    final slashPath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.43)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.5,
        size.width * 0.78,
        size.height * 0.33,
      )
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.62,
        size.width * 0.18,
        size.height * 0.53,
      )
      ..close();

    final starPath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.37)
      ..lineTo(size.width * 0.28, size.height * 0.46)
      ..lineTo(size.width * 0.18, size.height * 0.54)
      ..lineTo(size.width * 0.12, size.height * 0.43)
      ..lineTo(size.width * 0.02, size.height * 0.4)
      ..lineTo(size.width * 0.13, size.height * 0.34)
      ..lineTo(size.width * 0.17, size.height * 0.22)
      ..close();

    canvas.drawPath(aPath, paint);
    canvas.drawPath(slashPath, paint);
    canvas.drawPath(starPath, paint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
