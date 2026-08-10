import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_button_styles.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/network_client.dart';
import '../utils/secure_screen.dart';
import '../widgets/app_icon_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard immediately to expand viewport height and prevent layout overflow
    FocusScope.of(context).unfocus();

    HapticService.medium();
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();

    try {
      await AuthService().forgotPassword(email);

      if (!mounted) return;

      showAppIconDialog(
        context,
        barrierDismissible: false,
        // Preserves this screen's existing always-dark presentation (it has
        // no light/dark awareness of its own today) rather than adopting
        // the app's real theme.
        isDarkMode: true,
        icon: Icons.mail_outline_rounded,
        iconColor: AppTheme.accentPurple,
        title: 'Reset Email Sent!',
        message:
            'We have sent a secure password reset link to $email. Please check your inbox and follow the instructions to set your new password.',
        primaryLabel: 'Back to Sign In',
        onPrimaryPressed: () {
          HapticService.light();
          Navigator.pop(context); // Pop back to login screen
        },
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      // The backend now always responds with the same generic message
      // regardless of whether the account exists, so there is no longer a
      // distinct "account not found" case to special-case here.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
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

  @override
  Widget build(BuildContext context) {
    const bgColor = AppTheme.black;
    const textColor = AppTheme.white;
    const boxBg = AppTheme.darkCard;

    return SecureScreenGuard(
      // Phase 6: authentication on screen - screenshots, screen
      // recording and the recent-apps thumbnail are blocked while this
      // screen is mounted (Android; see SecureScreen for the iOS limits).
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Forgot Password',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your email address to receive a 6-digit OTP verification code to reset your password.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email Address
                  const Text('Email Address',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: textColor),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: boxBg,
                      hintText: 'you@example.com',
                      hintStyle: const TextStyle(color: AppTheme.mediumGray),
                      prefixIcon: const Icon(Icons.mail_outline_rounded,
                          color: AppTheme.mediumGray, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppTheme.accentPurple, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty)
                        return 'Please enter your email';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // Action button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: AppButtonStyles.primary(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'Send Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
