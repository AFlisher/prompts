import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// SEC-0.1 - obtains Play Integrity tokens (Standard API) for the handful of
/// requests worth attesting, and does nothing else with them.
///
/// ALL TRUST DECISIONS BELONG EXCLUSIVELY TO THE BACKEND (SEC-0.2).
///
/// This class never decodes, parses, inspects or acts on a token. It cannot:
/// the token is encrypted and only Google's servers can read the verdict. That
/// asymmetry is the whole control. Anything this client concluded about its own
/// integrity would be a value the attacker controls - see
/// [DeviceIntegrityService] (SEC-13.4) for the same lesson in miniature.
///
/// Consequences that follow, and must not be "improved" later:
///
///  * Only the opaque token crosses the wire. Never a boolean, never a parsed
///    field, never a verdict.
///  * Failure is not blocking. If a token cannot be obtained the request is
///    sent without one and the backend decides - it is the only party that can
///    tell "attacker stripped the header" from "Play Services is broken", and
///    only if the client stops pre-judging that for it.
///  * Tokens are never cached. Google's guidance: caching integrity verdicts
///    increases proxying risk. Only the native provider is cached.
class DeviceIntegrityTokenService {
  static const MethodChannel _channel = MethodChannel('styliai/play_integrity');

  /// Warm-up is off the critical path, so it gets room. Google reports typical
  /// warm-up latency of a few seconds, with most under 10s.
  static const Duration warmUpTimeout = Duration(seconds: 20);

  /// The on-demand request is ON the critical path, in front of a user action,
  /// so it gets a tight bound. Google reports a few hundred milliseconds
  /// average for standard requests; 8s is a generous ceiling before we give up
  /// and let the request proceed unattested.
  static const Duration tokenTimeout = Duration(seconds: 8);

  /// Non-secret: the Cloud project number is published in the app anyway.
  /// Absent means integrity is simply not requested - which is exactly how the
  /// feature stays dark until the Play Console prerequisites are in place.
  static const String cloudProjectNumberKey = 'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER';

  static bool _prepared = false;

  @visibleForTesting
  static bool get prepared => _prepared;

  /// Android only. iOS would need App Attest, which is a separate finding, and
  /// web has neither concept nor plugin.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Total by construction. `dotenv.env` *throws* NotInitializedError if
  /// `.env` never loaded, and main() deliberately swallows that load failure -
  /// so an unguarded read here would put an uncaught error on the post-frame
  /// startup path for a feature that is meant to be optional.
  static String? get _cloudProjectNumber {
    try {
      final value = dotenv.env[cloudProjectNumberKey];
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (_) {
      return null;
    }
  }

  /// Prepares the native token provider. Call once after the first frame, and
  /// again occasionally to keep the provider fresh - Google expires providers
  /// that go unused for too long.
  ///
  /// Never throws and never blocks anything.
  static Future<void> warmUp() async {
    if (!isSupported) return;

    final projectNumber = _cloudProjectNumber;
    if (projectNumber == null) {
      debugPrint(
        '[DeviceIntegrityTokenService] $cloudProjectNumberKey not set - '
        'integrity tokens disabled.',
      );
      return;
    }

    try {
      final ok = await _channel
          .invokeMethod<bool>('prepare', {'cloudProjectNumber': projectNumber})
          .timeout(warmUpTimeout);
      _prepared = ok ?? false;
    } catch (e) {
      _prepared = false;
      debugPrint('[DeviceIntegrityTokenService] warm-up failed: $e');
    }
  }

  /// A stable digest of the request being protected, which Google returns
  /// inside the token so the backend can confirm the request was not tampered
  /// with in transit.
  ///
  /// The backend must recompute this over the same canonical bytes; any
  /// disagreement about serialisation makes every check fail, so the exact
  /// input is part of the SEC-0.2 contract, not an implementation detail.
  static String requestHashFor(String canonicalRequest) {
    return base64Url.encode(sha256.convert(utf8.encode(canonicalRequest)).bytes);
  }

  /// Returns an opaque integrity token bound to [requestHash], or null.
  ///
  /// Null is an ordinary outcome, not an error: no Play Services, no network,
  /// unprepared provider, timeout, or a device that simply cannot attest. The
  /// caller sends the request anyway.
  static Future<String?> tokenFor(String requestHash) async {
    if (!isSupported || !_prepared) return null;

    try {
      return await _channel
          .invokeMethod<String>('requestToken', {'requestHash': requestHash})
          .timeout(tokenTimeout);
    } catch (e) {
      debugPrint('[DeviceIntegrityTokenService] token request failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _prepared = false;
  }

  @visibleForTesting
  static set preparedForTest(bool value) => _prepared = value;
}
