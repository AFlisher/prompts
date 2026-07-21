import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final VoidCallback? onVerified;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.onVerified,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  int _cooldownSeconds = 60;
  Timer? _timer;
  Timer? _verificationTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _startVerificationCheck();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      }
    });
  }

  void _handleVerificationSuccess() {
    if (!mounted) return;

    HapticService.medium();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Email verified successfully. Please sign in."),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _handleResendLink() async {
    if (!_canResend || _isLoading) return;

    HapticService.light();
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService().resendVerification(widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link resent to your email.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startVerificationCheck() {
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
          try {
            final isVerified = await AuthService().checkVerificationStatus(widget.email);
            if (isVerified) {
              timer.cancel();
              _handleVerificationSuccess();
            }
          } catch (e) {
            debugPrint('Verification check failed: $e');
          }
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          'Verify Email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'We\'ve sent a verification link to:\n${widget.email}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Custom holographic indicator
                        const Center(
                          child: _HologramVerificationIndicator(),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        const Text(
                          'Waiting for verification link detection...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        
                        const SizedBox(height: 32),

                        // Resend button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_canResend && !_isLoading) ? _handleResendLink : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentPurple,
                              disabledBackgroundColor: AppTheme.accentPurple.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white38,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : Text(
                                    _canResend ? 'Resend Link' : 'Resend in ${_cooldownSeconds}s',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),

                        // Back to Sign In Option
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              HapticService.light();
                              Navigator.popUntil(context, (route) => route.isFirst);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Back to Sign In',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HologramVerificationIndicator extends StatefulWidget {
  const _HologramVerificationIndicator();

  @override
  State<_HologramVerificationIndicator> createState() => _HologramVerificationIndicatorState();
}

class _HologramVerificationIndicatorState extends State<_HologramVerificationIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple circles
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final t = _pulseController.value;
              return Stack(
                alignment: Alignment.center,
                children: List.generate(3, (index) {
                  final scale = 1.0 + (index * 0.45) + (t * 0.45);
                  final opacity = (0.45 - (index * 0.15) - (t * 0.15)).clamp(0.0, 0.45);
                  return Container(
                    width: 90 * scale,
                    height: 90 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentPurple.withOpacity(opacity),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          
          // Rotating outer ring
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _RadarRingPainter(color: AppTheme.accentPurple),
                  ),
                ),
              );
            },
          ),

          // Central pulsing icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPurple.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingPainter extends CustomPainter {
  final Color color;
  _RadarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw some arcs to represent the rotating radar segments
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 0.35,
      false,
      paint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * 0.35,
      false,
      paint,
    );

    // Draw small orbiting dot
    final dotPaint = Paint()
      ..color = AppTheme.accentPink
      ..style = PaintingStyle.fill;
    
    final dotX = center.dx + radius * math.cos(math.pi * 0.35);
    final dotY = center.dy + radius * math.sin(math.pi * 0.35);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
