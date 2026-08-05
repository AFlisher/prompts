import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/legal_urls.dart';
import '../services/network_client.dart';
import '../theme/app_theme.dart';
import '../widgets/status_bar_style.dart';

/// Sprint 1 / B-1 — the in-app account deletion flow.
///
/// Required by Google Play's data deletion policy and App Store Guideline
/// 5.1.1(v). Both require the path to exist *inside the app*, not only as a
/// support email.
///
/// ─── Why a full screen rather than a dialog ─────────────────────────────────
///
/// Sign Out uses a dialog, and this deliberately does not copy it. Deletion is
/// irreversible and forfeits credits the user earned, so it needs room to say
/// exactly what is about to be destroyed before asking for confirmation. A
/// modal that a mis-tap can dismiss — or accept — is the wrong container for
/// the only action in this app that cannot be undone.
///
/// The typed confirmation is the same phrase the backend requires, so the
/// control the user sees and the control the server enforces are the same one
/// rather than two that can drift apart.
class DeleteAccountScreen extends StatefulWidget {
  final bool isDarkMode;

  /// True for password accounts, false for Google sign-in. Drives whether the
  /// password field is shown; the backend enforces the same rule regardless of
  /// what this widget renders.
  final bool requiresPassword;

  /// Test seam, matching the convention used by PaywallScreen and
  /// EditProfileScreen: lets a widget test drive the flow without a backend.
  final Future<void> Function({String? currentPassword})? deleteAccountOverride;

  /// Invoked after a successful deletion. The caller owns navigation, because
  /// this screen does not know what the signed-out root of the app is.
  final VoidCallback onDeleted;

  const DeleteAccountScreen({
    super.key,
    required this.isDarkMode,
    required this.requiresPassword,
    required this.onDeleted,
    this.deleteAccountOverride,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const String _phrase = 'DELETE';

  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The button's enabled state is derived from both fields, so both must
    // trigger a rebuild as they are typed.
    _confirmController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Case-sensitive, matching the backend exactly. Trimmed only for surrounding
  /// whitespace, which keyboards add on their own and the user did not intend.
  bool get _phraseMatches => _confirmController.text.trim() == _phrase;

  bool get _passwordProvided =>
      !widget.requiresPassword || _passwordController.text.isNotEmpty;

  bool get _canSubmit => _phraseMatches && _passwordProvided && !_isDeleting;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    HapticService.heavy();
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      final delete = widget.deleteAccountOverride ?? _authService.deleteAccount;
      await delete(
        currentPassword:
            widget.requiresPassword ? _passwordController.text : null,
      );

      if (!mounted) return;
      widget.onDeleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        // AuthException carries the backend's own user-facing message (wrong
        // password, missing confirmation). Anything else is a transport
        // failure and goes through the shared mapper so a raw
        // SocketException never reaches the screen.
        _error = e is AuthException ? e.message : friendlyNetworkErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bg = isDark ? AppTheme.black : AppTheme.lightBackground;
    final textColor = isDark ? AppTheme.white : AppTheme.black;
    final surface = isDark ? AppTheme.darkCard : AppTheme.white;

    return StatusBarStyle(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Go back',
                      child: GestureDetector(
                        onTap: () {
                          HapticService.light();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: textColor),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: textColor, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Delete Account',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(color: textColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                _WarningPanel(isDark: isDark),

                const SizedBox(height: 24),
                Text(
                  'This permanently deletes:',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ..._deletedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.remove_circle_outline_rounded,
                              size: 15, color: Colors.redAccent),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.85),
                                fontSize: 14,
                                height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                if (LegalUrls.isConfigured)
                  Semantics(
                    link: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticService.light();
                        _showPolicyUrl(context, isDark);
                      },
                      child: const Text(
                        'What happens to my data?',
                        style: TextStyle(
                          color: AppTheme.accentPurple,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),
                Text(
                  'Type $_phrase to confirm',
                  style: TextStyle(
                      color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _Field(
                  controller: _confirmController,
                  hint: _phrase,
                  isDark: isDark,
                  surface: surface,
                  textColor: textColor,
                  semanticLabel: 'Confirmation phrase',
                  autocorrect: false,
                ),

                if (widget.requiresPassword) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Enter your password',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _passwordController,
                    hint: 'Current password',
                    isDark: isDark,
                    surface: surface,
                    textColor: textColor,
                    semanticLabel: 'Current password',
                    obscure: true,
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Semantics(
                    button: true,
                    enabled: _canSubmit,
                    label: 'Permanently delete my account',
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        disabledBackgroundColor:
                            Colors.redAccent.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text(
                              'Permanently Delete Account',
                              style: TextStyle(
                                  fontSize: 15.5, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: _isDeleting ? null : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPolicyUrl(BuildContext context, bool isDark) {
    // Shown rather than launched: the deletion policy is most useful at exactly
    // this moment, and bouncing the user out to a browser mid-flow is how a
    // half-finished deletion becomes an abandoned one.
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('What happens to my data',
            style: TextStyle(color: isDark ? AppTheme.white : AppTheme.black)),
        content: Text(
          'Everything listed on the previous screen is erased immediately and '
          'cannot be recovered.\n\nWe keep one record that the deletion '
          'happened. It contains no name, email or content.\n\nFull details:\n'
          '${LegalUrls.accountDeletion}',
          style: TextStyle(
              color: isDark ? AppTheme.lightGray : AppTheme.mediumGray,
              fontSize: 13.5,
              height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static const List<String> _deletedItems = [
    'Your profile, name and email address',
    'Every image you have generated, and its stored file',
    'Your profile picture',
    'Your remaining credits and full transaction history',
    'Your favourites, notifications and feedback',
    'All signed-in devices — you will be signed out everywhere',
  ];
}

class _WarningPanel extends StatelessWidget {
  final bool isDark;
  const _WarningPanel({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This cannot be undone.\n\nThere is no grace period and no way to '
              'recover your account or images afterwards. Any credits you have '
              'left will be lost.',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final Color surface;
  final Color textColor;
  final String semanticLabel;
  final bool obscure;
  final bool autocorrect;

  const _Field({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.surface,
    required this.textColor,
    required this.semanticLabel,
    this.obscure = false,
    this.autocorrect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.35)),
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: textColor.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: textColor.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}
