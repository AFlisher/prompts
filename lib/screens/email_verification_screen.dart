import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/network_client.dart';

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

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  int _cooldownSeconds = 60;
  Timer? _timer;
  Timer? _verificationTimer;
  bool _canResend = false;

  // ---------------------------------------------------------------------------
  // SEC-19.4 — verification polling.
  //
  // This screen polled `GET /api/auth/status` on a FIXED 2-second interval with
  // no backoff, no attempt cap, and no stop condition other than success or
  // leaving the screen. Errors were swallowed into a debugPrint, so a failing
  // backend did not slow the loop down - it kept firing every 2 seconds
  // regardless. That is 30 requests/minute per waiting device, sustained for as
  // long as the screen is open, including while the app sits backgrounded.
  //
  // Each request is individually cheap (one indexed lookup on email), which is
  // why the audit rates this Low. What makes it worth fixing is the shape of
  // the load rather than its size: it is a FIXED FLOOR proportional to
  // concurrent signups rather than to useful work, and it does not back off
  // when the backend is struggling - precisely when a client should. During a
  // launch spike the signup funnel generates its heaviest backend load at
  // exactly the moment the rest of the system is busiest.
  //
  // The server-side limiter (statusPollLimiter, 90/min) never corrected this
  // because 30/min sits comfortably under it: the pattern was designed to stay
  // inside its own cap, so it could never self-correct.
  //
  // Three changes, matching the audit's recommendation:
  //   1. Exponential backoff 2s -> 4s -> 8s -> ... -> 30s ceiling.
  //   2. An overall deadline, after which polling STOPS and the user gets an
  //      explicit "Check again" button. An indefinite poll is the part that
  //      makes an abandoned screen a permanent load source.
  //   3. Paused while the app is backgrounded, and resumed on return. A user
  //      who switches to their mail app to click the link is the common case,
  //      and that is exactly when the old timer kept firing unseen.
  // ---------------------------------------------------------------------------

  static const Duration _initialPollInterval = Duration(seconds: 2);
  static const Duration _maxPollInterval = Duration(seconds: 30);
  static const Duration _pollDeadline = Duration(minutes: 5);

  Duration _pollInterval = _initialPollInterval;
  // Elapsed polling time is ACCUMULATED from the intervals actually waited
  // rather than measured against DateTime.now(). Two reasons: a wall-clock
  // deadline keeps counting while the app is backgrounded and polling is
  // paused - so a user who spends four minutes in their mail app would return
  // to a screen that had already given up without ever having checked - and
  // wall-clock time cannot be advanced by a widget test's fake clock, which
  // would make this policy untestable.
  Duration _elapsedPolling = Duration.zero;
  bool _pollingStopped = false;
  bool _checkInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldown();
    _startVerificationCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Returning to the app is the single most likely moment for the state to
      // have changed - the user probably just clicked the link. Restart from
      // the fast interval rather than resuming wherever the backoff had got to.
      if (!_pollingStopped) {
        _pollInterval = _initialPollInterval;
        _scheduleNextCheck(immediate: true);
      }
    } else {
      // paused / inactive / detached / hidden - stop making requests for a
      // screen nobody is looking at.
      _verificationTimer?.cancel();
      _verificationTimer = null;
    }
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
        SnackBar(content: Text(friendlyNetworkErrorMessage(e))),
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
    _elapsedPolling = Duration.zero;
    _pollInterval = _initialPollInterval;
    _pollingStopped = false;
    _scheduleNextCheck();
  }

  /// Schedules exactly one future check.
  ///
  /// A one-shot `Timer` rather than `Timer.periodic`, because the interval has
  /// to grow between ticks - and because `periodic` fires on a fixed schedule
  /// regardless of how long each request took, which is how a slow backend
  /// ends up with overlapping in-flight requests from one client.
  void _scheduleNextCheck({bool immediate = false}) {
    _verificationTimer?.cancel();
    if (_pollingStopped) return;

    _verificationTimer = Timer(
      immediate ? Duration.zero : _pollInterval,
      _runVerificationCheck,
    );
  }

  Future<void> _runVerificationCheck() async {
    if (!mounted || _pollingStopped) return;

    // Never overlap requests. Without this, a backend slow enough to exceed the
    // poll interval would accumulate concurrent requests from a single device -
    // the opposite of backing off.
    if (_checkInFlight) {
      _scheduleNextCheck();
      return;
    }

    _checkInFlight = true;
    try {
      final isVerified = await AuthService().checkVerificationStatus(widget.email);
      if (!mounted) return;
      if (isVerified) {
        _pollingStopped = true;
        _verificationTimer?.cancel();
        _handleVerificationSuccess();
        return;
      }
    } catch (e) {
      // Deliberately does NOT reset the interval. The old code swallowed the
      // error and kept firing at full rate, so a struggling backend received
      // exactly as much traffic as a healthy one; letting the backoff continue
      // through failures is the behaviour the audit asked for.
      debugPrint('Verification check failed: $e');
    } finally {
      _checkInFlight = false;
    }

    if (!mounted || _pollingStopped) return;

    // Stop entirely once the deadline passes. The user is not stranded - the
    // "Check Again" button restarts polling on demand - but an abandoned
    // screen stops being a permanent source of load.
    _elapsedPolling += _pollInterval;
    if (_elapsedPolling >= _pollDeadline) {
      setState(() => _pollingStopped = true);
      return;
    }

    // Exponential backoff with a ceiling: 2s, 4s, 8s, 16s, 30s, 30s, ...
    final doubled = _pollInterval * 2;
    _pollInterval = doubled > _maxPollInterval ? _maxPollInterval : doubled;
    _scheduleNextCheck();
  }

  /// Manual re-check after the automatic poll has given up.
  Future<void> _handleCheckAgain() async {
    if (_isLoading) return;
    HapticService.light();
    setState(() {
      _pollingStopped = false;
    });
    _startVerificationCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                        
                        // SEC-19.4: the copy has to tell the truth about which
                        // state the screen is in. Once automatic polling has
                        // stopped, saying "waiting..." while nothing is
                        // actually being checked would leave the user staring
                        // at a screen that will never update on its own.
                        Text(
                          _pollingStopped
                              ? "Still not verified. Tap Check Again once you've clicked the link."
                              : 'Waiting for verification link detection...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.mediumGray,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        if (_pollingStopped) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleCheckAgain,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text(
                                'Check Again',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentPurple,
                                side: const BorderSide(color: AppTheme.accentPurple),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],

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
