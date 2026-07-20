import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../screens/paywall_screen.dart';
import '../services/haptic_service.dart';

/// How long the capsule's theme-driven color/shadow/text/icon transitions
/// take - shared by every animated piece here so they all move in lockstep.
const Duration _kThemeTransitionDuration = Duration(milliseconds: 280);
const Curve _kThemeTransitionCurve = Curves.easeInOutCubic;

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
    final profile = ProfileProvider.of(context).profile;
    final creditManager = CreditProvider.of(context);
    final initials = (profile?.fullName ?? '').trim().isNotEmpty
        ? profile!.fullName![0].toUpperCase()
        : 'U';

    // Light Mode: unchanged - the capsule stays the same dark pill it's
    // always been (AppTheme.black, white content). Dark Mode: instead of
    // matching the page's own dark surface, it deliberately inverts to the
    // Light Theme's cream/off-white background (never pure white) so it
    // reads as a bright, premium accent floating on the dark page - the
    // exact same color the whole app already uses as its light-mode
    // scaffold background (see home_screen.dart's bgColor), just reused
    // here rather than introducing a new one.
    final capsuleBg = isDarkMode ? AppTheme.lightBackground : AppTheme.black;
    final capsuleFg = isDarkMode ? AppTheme.black : Colors.white;

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
        AnimatedContainer(
          duration: _kThemeTransitionDuration,
          curve: _kThemeTransitionCurve,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: capsuleBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.themeAwareShadow(isDarkMode),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeToggleIcon(
                isDarkMode: isDarkMode,
                color: capsuleFg,
                onTap: onToggleDarkMode,
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaywallScreen(isDarkMode: isDarkMode),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    // Before the first fetchWallet() resolves, credits hasn't
                    // loaded the user's real balance yet - render a
                    // placeholder instead of a number that would flash and
                    // then visibly change to the real one a moment later.
                    if (!creditManager.isInitialized)
                      Shimmer.fromColors(
                        baseColor: capsuleFg.withValues(alpha: 0.25),
                        highlightColor: capsuleFg.withValues(alpha: 0.6),
                        child: AnimatedContainer(
                          duration: _kThemeTransitionDuration,
                          curve: _kThemeTransitionCurve,
                          width: 14,
                          height: 13,
                          decoration: BoxDecoration(
                            color: capsuleFg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      )
                    else
                      AnimatedDefaultTextStyle(
                        duration: _kThemeTransitionDuration,
                        curve: _kThemeTransitionCurve,
                        style: TextStyle(
                          color: capsuleFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        child: Text('${creditManager.credits}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty
                      ? null
                      : const LinearGradient(
                          colors: [AppTheme.accentPurple, AppTheme.accentBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  image: profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(profile.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profile?.avatarUrl != null && profile!.avatarUrl!.trim().isNotEmpty
                    ? null
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The sun/moon theme toggle. A tap does two things at once, kept in sync
/// on the same duration/curve as the capsule's own color transition:
/// the icon glyph itself swaps immediately (driven by [isDarkMode] changing
/// on the next frame), while this widget plays a full 360deg spin with a
/// slight mid-flight scale pop (1.0 -> 1.08 -> 1.0) - a small, elegant
/// "spin to reveal" flourish rather than anything flashy or long-running.
/// Deliberately a full turn, not a half turn: the icon must always come to
/// rest upright (a moon rotated 180deg reads as sideways/upside-down), and
/// 360deg is visually identical to 0deg while still spinning mid-flight.
class _ThemeToggleIcon extends StatefulWidget {
  final bool isDarkMode;
  final Color color;
  final VoidCallback onTap;

  const _ThemeToggleIcon({
    required this.isDarkMode,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ThemeToggleIcon> createState() => _ThemeToggleIconState();
}

class _ThemeToggleIconState extends State<_ThemeToggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kThemeTransitionDuration,
  );
  late final Animation<double> _spin = CurvedAnimation(
    parent: _controller,
    curve: _kThemeTransitionCurve,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          final t = _spin.value;
          // Smooth 0 -> 1.08 -> 1.0 pop, peaking mid-flight - not the more
          // common overshoot-then-settle spring, just a single gentle sine
          // bump, in keeping with "minimal, not flashy".
          final scale = 1.0 + (sin(t * pi) * 0.08);
          return Transform.rotate(
            angle: t * 2 * pi, // 0 -> 360deg - always finishes upright
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: widget.color),
          duration: _kThemeTransitionDuration,
          curve: _kThemeTransitionCurve,
          builder: (context, color, _) => Icon(
            widget.isDarkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: color,
            size: 22,
          ),
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
