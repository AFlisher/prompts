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
import 'package:prombt_app/screens/reset_password_screen.dart';

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
  group('ForgotPasswordScreen & ResetPasswordScreen', () {
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

    testWidgets('ResetPasswordScreen validation and success flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: ResetPasswordScreen(email: 'test@example.com'),
      ));
      await tester.pump();

      expect(find.text('Reset Password'), findsNWidgets(2));
      expect(find.text('Set a strong password for test@example.com'), findsOneWidget);

      // Test empty input validation
      await tester.tap(find.text('Reset Password').at(1)); // The button, index 1
      await tester.pump();
      expect(find.text('Please enter a password'), findsOneWidget);

      // Test mismatch validation
      await tester.enterText(find.byType(TextFormField).at(0), 'Ahmed@1234');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ahmed@1111');
      await tester.tap(find.text('Reset Password').at(1));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);

      // Test valid input and simulated reset
      await tester.enterText(find.byType(TextFormField).at(1), 'Ahmed@1234');
      await tester.tap(find.text('Reset Password').at(1));
      await tester.pump();

      // Wait for delay
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should show password reset confirmation dialog
      expect(find.text('Password Reset!'), findsOneWidget);
      expect(find.text('Back to Login'), findsOneWidget);
    });
  });

  // ── EMAIL VERIFICATION SCREEN ─────────────────────────────────────────────
  group('EmailVerificationScreen', () {
    Widget buildVerification() => MaterialApp(
          home: const EmailVerificationScreen(email: 'ahmed@test.com'),
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
  });
}
