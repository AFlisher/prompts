import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const AppHeader({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? AppTheme.white : AppTheme.black;

    return Row(
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
                onTap: onToggleDarkMode,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  isDarkMode
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
