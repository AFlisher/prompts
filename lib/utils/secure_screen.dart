import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Phase 6 — screenshot and recorder protection for individual screens.
///
/// Android applies `FLAG_SECURE`, which blocks screenshots and screen
/// recording AND blanks the window in the recent-apps switcher. That third
/// effect is the one worth having: the task-switcher thumbnail is a screenshot
/// the user never asked for and never sees being taken, and it persists after
/// they leave the screen.
///
/// ─── Deliberately not app-wide ───────────────────────────────────────────
///
/// Users screenshot their own generated images to save and share them - that is
/// the product working, and blocking it would be a bug. Only screens that put
/// credentials, account details or billing on display are protected.
///
/// ─── iOS: a documented limitation, not an oversight ──────────────────────
///
/// iOS has no equivalent of FLAG_SECURE. There is no supported API that
/// prevents a screenshot; the platform only offers `UIScreen.isCaptured` and
/// `userDidTakeScreenshotNotification`, which report a capture that has already
/// happened. The common workaround (a hidden `UITextField` with
/// `isSecureTextEntry` used as a rendering host) relies on undocumented
/// behaviour of a private view hierarchy and has broken across iOS releases.
///
/// This calls the channel on iOS anyway rather than skipping it: the platform
/// side simply has no handler, so it returns notImplemented, which surfaces
/// here as `false`. If an iOS host is added later it can implement whatever
/// best-effort protection is then supportable, with no Dart change. iOS has
/// never been built for this project (there is no Podfile), so nothing is
/// claimed about it today beyond that.
class SecureScreen {
  static const MethodChannel _channel = MethodChannel('styliai/secure_screen');

  /// How many mounted widgets currently want the window secured.
  ///
  /// Reference-counted, not a boolean. Two protected screens can be on the
  /// stack at once - opening Edit Profile from Profile does exactly that - and
  /// a plain boolean would clear the flag when the inner one pops, silently
  /// unprotecting the screen still on display.
  static int _holders = 0;

  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static void resetForTest() => _holders = 0;

  /// Overridable so tests can observe the calls without a platform host.
  @visibleForTesting
  static Future<bool> Function(bool enabled)? applyOverride;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _apply(bool enabled) async {
    final override = applyOverride;
    if (override != null) return override(enabled);

    if (!_isSupportedPlatform) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setSecure', {'enabled': enabled});
      return result ?? false;
    } on MissingPluginException {
      // No host handler - iOS today, or a platform we do not build for. Not an
      // error worth surfacing: the screen must still open.
      return false;
    } catch (_) {
      // A device that refuses the flag must never be the reason a screen fails
      // to render. Protection is best-effort by nature; availability is not.
      return false;
    }
  }

  /// Marks one more widget as needing protection. Only the first acquire
  /// actually touches the window.
  static Future<void> acquire() async {
    _holders++;
    if (_holders == 1) await _apply(true);
  }

  /// Releases one holder. Only the last release clears the flag.
  static Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) await _apply(false);
  }
}

/// Wraps a screen so it is protected for exactly as long as it is mounted.
///
/// A widget rather than a manual acquire/release pair in each screen's
/// initState/dispose, because the manual version is one forgotten `dispose`
/// away from leaving the whole app secured - which would silently break
/// screenshotting a generated image, the one thing users are meant to do.
class SecureScreenGuard extends StatefulWidget {
  final Widget child;

  const SecureScreenGuard({super.key, required this.child});

  @override
  State<SecureScreenGuard> createState() => _SecureScreenGuardState();
}

class _SecureScreenGuardState extends State<SecureScreenGuard> {
  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
