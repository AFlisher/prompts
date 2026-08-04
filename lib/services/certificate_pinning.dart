import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// SEC-12.1 — certificate pinning for backend traffic.
///
/// Restricts TLS trust for calls to our own API from the ~150 public roots the
/// platform ships with, down to the two ISRG anchors in
/// assets/certs/backend_roots.pem. Anything signed by anything else - a
/// corporate middlebox, a user-installed root, Charles, mitmproxy, a
/// compromised CA outside that set - fails the TLS handshake before a single
/// byte of the request is written.
///
/// ## Why roots and not leaf SPKI
///
/// The audit asks for SPKI pinning, and leaf-SPKI is the stronger control on
/// paper. It is the wrong control here, for a reason specific to this
/// deployment: the backend runs on Railway behind a *Railway-managed* Let's
/// Encrypt certificate (`CN=*.up.railway.app`) that renews roughly every 90
/// days. We do not own the key, do not control the renewal, and cannot know the
/// next public key in advance. A leaf or leaf-SPKI pin would therefore stop
/// working every quarter, on a date nobody chose, and the fix would have to
/// clear an app-store review before any user could log in again. That is not a
/// security control, it is a scheduled outage.
///
/// Root pinning keeps working across every renewal and still removes every
/// practical interception path. What it does not defend against is
/// mis-issuance *by the pinned CA itself* - a narrower residual risk than a
/// self-inflicted quarterly outage, and one that Certificate Transparency and
/// CAA already address at the CA layer.
///
/// ## Fail closed
///
/// [badCertificateCallback] is wired to a function that always returns false,
/// and the context is built with `withTrustedRoots: false`. There is no
/// override, no debug bypass, no "accept all certificates" branch, and no
/// runtime pin download - the anchors ship inside the binary. If the bundle
/// cannot be loaded the client is not built and the caller gets an ordinary
/// network failure, because a pinning layer that silently degrades to the
/// system trust store is worse than none: it reports success while providing
/// nothing.
///
/// ## Scope
///
/// This client is used for calls to our own backend only. Supabase (its own SDK
/// client, Google Trust Services roots) and generated-image downloads from
/// Supabase storage are deliberately NOT routed through it - a single trust set
/// covering every host the app touches would have to include Google's roots
/// too, which weakens the backend pin, and pinning the image CDN would break
/// picture loading on a CA change for no credential-bearing traffic. Pinning
/// those is a separate decision with its own rotation risk.
class CertificatePinning {
  CertificatePinning._();

  /// Which anchor bundle to load. Environment-aware so a staging backend behind
  /// a different CA can ship its own anchors, NOT so that any environment can
  /// turn pinning off - there is no such setting.
  static const String environmentKey = 'PIN_ENVIRONMENT';

  static const Map<String, String> _bundles = {
    'prod': 'assets/certs/backend_roots.pem',
    'staging': 'assets/certs/backend_roots.pem',
  };

  static const String _defaultEnvironment = 'prod';

  static http.Client? _client;

  /// The pinned client, or null if pinning could not be initialised.
  ///
  /// Null is deliberately not "fall back to an unpinned client". Callers treat
  /// it as a hard failure; see [client].
  static http.Client? get maybeClient => _client;

  /// True once [initialize] has successfully built a pinned client.
  static bool get isInitialized => _client != null;

  /// Resolves the anchor bundle for [environment], falling back to prod rather
  /// than to "no pinning" for an unrecognised value.
  static String bundlePathFor(String? environment) {
    final key = (environment ?? '').trim().toLowerCase();
    return _bundles[key] ?? _bundles[_defaultEnvironment]!;
  }

  /// Builds the pinned client. Call once, before any backend request.
  ///
  /// Returns true on success. On failure the client stays null and every
  /// backend call fails closed - which is the intended behaviour, because a
  /// build that cannot load its own trust anchors has no way to tell a real
  /// server from an attacker's.
  static Future<bool> initialize({String? environment}) async {
    if (_client != null) return true;

    try {
      final path = bundlePathFor(environment);
      final pem = await rootBundle.load(path);

      // withTrustedRoots: false is the pin. The platform's own CA store is not
      // consulted at all; only the anchors below can terminate a chain.
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(pem.buffer.asUint8List());

      final httpClient = HttpClient(context: context)
        // Reached only when the chain has ALREADY failed validation against the
        // pinned anchors. Returning true here is the single line that would
        // silently undo this entire finding, so it returns false, always, with
        // no parameter that could make it do otherwise.
        ..badCertificateCallback = _rejectAlways;

      _client = IOClient(httpClient);
      return true;
    } catch (e) {
      // Never rethrow: a startup failure must not crash the app. It must,
      // however, leave _client null so nothing silently talks unpinned TLS.
      debugPrint('[CertificatePinning] failed to initialise: $e');
      _client = null;
      return false;
    }
  }

  /// Always false. Named rather than inline so it is greppable and so a test
  /// can assert on it directly.
  static bool _rejectAlways(X509Certificate cert, String host, int port) => false;

  @visibleForTesting
  static bool Function(X509Certificate, String, int) get rejectAlways => _rejectAlways;

  @visibleForTesting
  static void resetForTest() => _client = null;

  @visibleForTesting
  static void setClientForTest(http.Client? client) => _client = client;
}
