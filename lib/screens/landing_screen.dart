import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final startTime = DateTime.now();

    final authService = AuthService();
    bool isSessionRestored = false;
    try {
      isSessionRestored = await authService.ensureValidSession();
    } catch (e) {
      debugPrint("[LandingScreen] Error verifying session during auto-login: $e");
    }

    final elapsed = DateTime.now().difference(startTime);
    const minDuration = Duration(milliseconds: 2000); // minimum 2 seconds splash duration
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;

    if (isSessionRestored && authService.currentUser != null) {
      debugPrint("[LandingScreen] Auto-login successful. Navigating to Home.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      debugPrint("[LandingScreen] Auto-login failed or no session. Navigating to Login.");
      // Ensure we clear any stale tokens or cached session on failure
      await authService.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Styled calligraphy logo A
            SizedBox(
              width: 140,
              height: 120,
              child: CustomPaint(
                painter: _LogoPainter(color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            
            // Brand Name & Sparkle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accentPink,
                    size: 36,
                  ),
                ),
                const Text(
                  'StyliAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
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
