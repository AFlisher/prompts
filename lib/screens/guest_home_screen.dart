import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../services/haptic_service.dart';

/// The only screen an unauthenticated user ever sees. Deliberately shows no
/// Categories/Styles/Trending/Recommended content and never touches
/// StyleProvider or any other account-scoped manager - those only exist to
/// serve an authenticated MainShell, and the backend now rejects their
/// endpoints without a valid JWT anyway (see categoryRoutes.js/styleRoutes.js).
/// Reached from LandingScreen when no session could be restored, and from
/// MainShell/ProfileScreen on sign-out - the single "logged out" destination.
class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  void _openLogin(BuildContext context) {
    HapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openRegister(BuildContext context) {
    HapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const SizedBox(
                width: 120,
                height: 104,
                child: CustomPaint(painter: const _LogoPainter(color: Colors.white)),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accentPink,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'StyliAI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              const Text(
                'Welcome to StyliAI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in or create an account to explore AI styles and generate amazing photos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentPink],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openLogin(context),
                      child: const Center(
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _openRegister(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  const _LogoPainter({required this.color});

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
