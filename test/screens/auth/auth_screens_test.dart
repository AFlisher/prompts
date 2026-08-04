// test/screens/auth/auth_screens_test.dart
//
// Tests for:
//   - LandingScreen (splash)
//   - LoginScreen
//   - RegisterScreen
//   - EmailVerificationScreen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/screens/landing_screen.dart';
import 'package:prombt_app/screens/login_screen.dart';
import 'package:prombt_app/screens/register_screen.dart';
import 'package:prombt_app/screens/email_verification_screen.dart';
import 'package:prombt_app/screens/forgot_password_screen.dart';

void main() {
  // ── LANDING / SPLASH ───────────────────────────────────────────────────────
  group('LandingScreen', () {
    testWidgets('renders StyliAI brand text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      expect(find.text('StyliAI'), findsOneWidget);
    });

    testWidgets('renders logo sparkle icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('has black background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LandingScreen()),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0A0A0A));
    });
  });

  // ── LOGIN SCREEN ──────────────────────────────────────────────────────────
  group('LoginScreen', () {
    Widget buildLogin() =>
        const MaterialApp(home: LoginScreen());

    testWidgets('renders Welcome Back title', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('renders Google sign-in button', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders Create Account link', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('shows validation error on empty submit', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      await tester.enterText(
          find.byType(TextFormField).first, 'notanemail');
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('password field is obscured by default', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();
      // TextFormField wraps a TextField — check the inner widget
      final innerFields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      // The last EditableText corresponds to the password field
      expect(innerFields.last.obscureText, isTrue);
    });
  });

  // ── REGISTER SCREEN ───────────────────────────────────────────────────────
  group('RegisterScreen', () {
    Widget buildRegister() =>
        const MaterialApp(home: RegisterScreen());

    testWidgets('renders Create Account title', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      // 'Create Account' appears in both the page title and the submit button
      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('renders three input fields (name, email, password)',
        (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      expect(find.byType(TextFormField), findsAtLeastNWidgets(3));
    });

    testWidgets('renders terms & conditions checkbox', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('shows snackbar if terms not agreed', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      // Fill in valid data first
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Ahmed');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'ahmed@test.com');
      await tester.enterText(
          find.byType(TextFormField).at(2), 'Ahmed@1234');
      // Tap the ElevatedButton (not the title which also says 'Create Account')
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Please agree to the Terms & Conditions'),
          findsOneWidget);
    });

    testWidgets('shows name validation error on empty submit', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Please enter your full name'), findsOneWidget);
    });

    testWidgets('shows password strength validation errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildRegister());
      await tester.pump();

      // Too short
      await tester.enterText(find.byType(TextFormField).at(2), 'Ab1!');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      // No uppercase
      await tester.enterText(find.byType(TextFormField).at(2), 'abcdef1!');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Must contain at least one uppercase letter'), findsOneWidget);

      // No special character
      await tester.enterText(find.byType(TextFormField).at(2), 'Abcdef12');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Must contain at least one special character (!@#\$&*~)'), findsOneWidget);
    });

    testWidgets('Sign In link navigates back', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pump();
      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  // ── FORGOT PASSWORD & RESET PASSWORD SCREEN ────────────────────────────────
  group('ForgotPasswordScreen', () {
    testWidgets('ForgotPasswordScreen validation and navigation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump();

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Send Code'), findsOneWidget);

      // Submit empty email
      await tester.tap(find.text('Send Code'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField), 'invalidemail');
      await tester.tap(find.text('Send Code'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });

  // ── EMAIL VERIFICATION SCREEN ─────────────────────────────────────────────
  group('EmailVerificationScreen', () {
    Widget buildVerification() => const MaterialApp(
          home: EmailVerificationScreen(email: 'ahmed@test.com'),
        );

    testWidgets('renders Verify Email title', (tester) async {
      await tester.pumpWidget(buildVerification());
      await tester.pump();
      expect(find.text('Verify Email'), findsOneWidget);
    });

    testWidgets('shows the destination email address', (tester) async {
      await tester.pumpWidget(buildVerification());
      await tester.pump();
      expect(find.textContaining('ahmed@test.com'), findsOneWidget);
    });

    testWidgets('renders hologram verification indicator', (tester) async {
      await tester.pumpWidget(buildVerification());
      await tester.pump();
      expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
    });

    testWidgets('renders Resend Link button with cooldown', (tester) async {
      await tester.pumpWidget(buildVerification());
      await tester.pump();
      expect(find.text('Resend in 60s'), findsOneWidget);
    });

    testWidgets('renders Back to Sign In button', (tester) async {
      await tester.pumpWidget(buildVerification());
      await tester.pump();
      expect(find.text('Back to Sign In'), findsOneWidget);
    });

    // ── SEC-19.4 — polling backoff, deadline and manual re-check ────────────
    //
    // In the widget test environment there is no pinned HTTP client, so
    // AuthService.checkVerificationStatus throws on every attempt. That is
    // precisely the scenario the finding is about: BEFORE this change the
    // failure was swallowed into a debugPrint and the timer kept firing every
    // 2 seconds forever, so a struggling backend received exactly as much
    // traffic as a healthy one and the loop could never self-correct.
    group('SEC-19.4 polling behaviour', () {
      /// Advances the fake clock until [finder] matches, or gives up.
      ///
      /// Driven by the condition rather than by a fixed pump count on purpose:
      /// the number of polls before the deadline is a consequence of the
      /// backoff curve, so hard-coding it would make the test restate the
      /// implementation and break whenever the curve is tuned. Returns whether
      /// the condition was reached.
      Future<bool> pumpUntil(
        WidgetTester tester,
        Finder finder, {
        int maxSteps = 80,
        Duration step = const Duration(seconds: 30),
      }) async {
        for (var i = 0; i < maxSteps; i++) {
          if (finder.evaluate().isNotEmpty) return true;
          await tester.pump(step);
        }
        return finder.evaluate().isNotEmpty;
      }

      testWidgets('keeps polling (no Check Again) before the deadline', (tester) async {
        await tester.pumpWidget(buildVerification());
        await tester.pump();

        // Well past the old 2s interval but far short of the 5-minute deadline.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 30));
        }

        expect(find.text('Check Again'), findsNothing);
        expect(
          find.text('Waiting for verification link detection...'),
          findsOneWidget,
        );

        // Let any pending timer settle so the test does not leak one.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      testWidgets('stops polling after the deadline and offers a manual re-check',
          (tester) async {
        await tester.pumpWidget(buildVerification());
        await tester.pump();

        // Advance past the 5-minute deadline.
        final stopped = await pumpUntil(tester, find.text('Check Again'));

        // The screen must not keep claiming it is waiting when it has stopped.
        expect(stopped, isTrue);
        expect(find.text('Check Again'), findsOneWidget);
        expect(
          find.text('Waiting for verification link detection...'),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      testWidgets('the manual re-check restarts polling', (tester) async {
        await tester.pumpWidget(buildVerification());
        await tester.pump();

        expect(await pumpUntil(tester, find.text('Check Again')), isTrue);

        await tester.tap(find.text('Check Again'));
        await tester.pump();

        // Back to the waiting state - the user is never stranded by the
        // deadline, which is what makes stopping acceptable in the first place.
        expect(find.text('Check Again'), findsNothing);
        expect(
          find.text('Waiting for verification link detection...'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      testWidgets('cancels its timer on dispose, leaving nothing pending',
          (tester) async {
        await tester.pumpWidget(buildVerification());
        await tester.pump(const Duration(seconds: 5));

        // Replacing the widget disposes the state. If the poll timer were not
        // cancelled, flutter_test would fail the test with a pending-timer
        // error - which is the assertion here.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 2));
      });
    });
  });
}
