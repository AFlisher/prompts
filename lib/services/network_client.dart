import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'certificate_pinning.dart';
import 'device_integrity_token_service.dart';

/// Centralized network timeout defaults (Release Candidate QA - Task 1).
/// Every direct HTTP call in the app applies one of these instead of
/// letting a request hang indefinitely.
abstract class NetworkTimeouts {
  /// Login, register, forgot password, token refresh, email verification.
  static const auth = Duration(seconds: 15);

  /// Everything else that just reads/writes a small JSON payload
  /// (categories, styles, favorites, notifications, wallet, profile).
  static const api = Duration(seconds: 20);

  /// Image generation and any multipart upload - these carry real file
  /// bytes and the backend does real work (AI generation), so they get
  /// meaningfully longer than a plain API call.
  static const upload = Duration(seconds: 60);
}

/// SEC-12.1. Thrown when the pinned client could not be built, so no backend
/// request is attempted at all.
///
/// This exists so the failure is loud in code and silent to the user: there is
/// deliberately no fallback to an unpinned client, because a pinning layer that
/// quietly degrades to the platform trust store reports success while providing
/// nothing. [friendlyNetworkErrorMessage] maps it to the same generic message a
/// dropped connection produces - the user is told the server is unreachable,
/// not that a security control failed.
class SecureConnectionUnavailableException implements Exception {
  const SecureConnectionUnavailableException();
  @override
  String toString() => 'Secure connection unavailable';
}

/// SEC-12.1. The pinned client every backend call must go through.
///
/// Throws rather than returning a plain client if pinning never initialised.
/// That is the fail-closed guarantee: there is no code path from a backend
/// service to an unpinned socket.
http.Client get backendClient {
  final client = CertificatePinning.maybeClient;
  if (client == null) throw const SecureConnectionUnavailableException();
  return client;
}

/// Thrown for any non-2xx response this layer doesn't have a more specific
/// exception for - carries the status code so [friendlyNetworkErrorMessage]
/// can distinguish e.g. a 500 from a 404 without parsing message text.
class HttpStatusException implements Exception {
  final int statusCode;
  final String message;
  const HttpStatusException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thrown once a request is still unauthorized after exactly one forced
/// token refresh + retry (see [AuthorizedHttpClient.send]) - the session is
/// genuinely dead, not just momentarily stale. Callers should treat this as
/// "already signed out" (the client that throws it has already called
/// [AuthService.signOut]).
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expired';
}

/// Maps any error a network call can throw to one short, user-safe message.
/// Never surfaces a raw SocketException/FormatException, a stack trace, or
/// any other internal exception text (Release Candidate QA - Task 3).
String friendlyNetworkErrorMessage(Object error) {
  if (error is SessionExpiredException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is HttpStatusException) {
    if (error.statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (error.statusCode >= 500) {
      return 'Something went wrong. Please try again later.';
    }
  }
  if (error is TimeoutException) {
    return 'The request timed out. Please try again.';
  }
  if (error is SocketException) {
    return "Couldn't connect to the server.";
  }
  // SEC-12.1: a pin mismatch and an unavailable pinned client both surface as
  // an ordinary connection failure. Naming the certificate would tell an
  // attacker their interception was detected, and would tell a real user
  // something they can neither understand nor act on.
  if (error is HandshakeException || error is TlsException) {
    return "Couldn't connect to the server.";
  }
  if (error is SecureConnectionUnavailableException) {
    return "Couldn't connect to the server.";
  }
  return 'Something unexpected happened.';
}

/// Shared "authorized request with a single forced-refresh retry" flow used
/// by every service that calls the backend with a Bearer token (ApiService,
/// WalletService). Centralizes what used to be duplicated per-service:
///  - building the Authorization header (each service's own _getHeaders())
///  - applying a timeout so no request hangs forever
///  - a single, non-looping 401 recovery path (Release Candidate QA -
///    Task 2): one forced token refresh, one retry, then sign out.
class AuthorizedHttpClient {
  /// SEC-0.1. Shared with AuthService, which attests login outside this client
  /// because the pre-auth endpoints have no Bearer token to build headers for.
  static const String integrityHeader = 'X-Integrity-Token';

  final AuthService _authService;

  AuthorizedHttpClient(this._authService);

  /// Builds request headers, proactively refreshing the access token first
  /// if it looks expired - unchanged from each service's previous private
  /// _getHeaders() implementation.
  Future<Map<String, String>> headers() async {
    try {
      await _authService.ensureValidSession();
    } catch (_) {
      // Swallowed exactly as before: a failed proactive check doesn't stop
      // the request from being attempted - the 401 path below is what
      // actually recovers or gives up.
    }

    final accessToken = await _authService.getAccessToken();
    final result = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      result['Authorization'] = 'Bearer $accessToken';
    }
    return result;
  }

  /// Sends a request built from [request] (called with a fresh set of
  /// headers each time, so it's safe to invoke again for the retry) with
  /// [timeout] applied. Only on a 401 does this attempt exactly one forced
  /// token refresh followed by one retry; if it's still 401 after that, the
  /// user is signed out and [SessionExpiredException] is thrown instead of
  /// retrying again - never an infinite loop.
  ///
  /// SEC-0.1: pass [integrityPayload] to attach a Play Integrity token. It is
  /// opt-in per call site, deliberately - attaching one to all 21 call sites
  /// would burn the 10,000/day account quota on reads like `getCategories` and
  /// leave nothing for the endpoints that actually move money. The protected
  /// set is the three money paths here plus login in AuthService.
  ///
  /// The token is opaque and is never inspected. If it cannot be obtained the
  /// request goes out without it: only the backend (SEC-0.2) can tell an
  /// attacker stripping the header from a device whose Play Services is
  /// broken, and it can only do that if this client stops guessing on its
  /// behalf.
  /// Sprint 2 / B-5. The header name the backend's Phase 7 middleware reads.
  static const String idempotencyHeader = 'Idempotency-Key';

  Future<http.Response> send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    required Duration timeout,
    String? integrityPayload,
    String? idempotencyKey,
  }) async {
    // Minted once per user action. Reused verbatim on the 401 retry below,
    // because the request being attested has not changed - and because a
    // second mint would burn a second unit of the daily quota for one tap.
    final integrityToken = integrityPayload == null
        ? null
        : await DeviceIntegrityTokenService.tokenFor(
            DeviceIntegrityTokenService.requestHashFor(integrityPayload),
          );

    final initialHeaders = await headers();
    _attachIntegrity(initialHeaders, integrityToken);
    _attachIdempotency(initialHeaders, idempotencyKey);
    var response = await _withTimeout(request(initialHeaders), timeout);

    if (response.statusCode == 401) {
      final refreshed =
          await _authService.ensureValidSession(forceRefresh: true);
      if (refreshed) {
        final retryHeaders = await headers();
        _attachIntegrity(retryHeaders, integrityToken);
        // The SAME key on the retry, deliberately. A refreshed token does not
        // make this a different logical request, and minting a second key here
        // would turn the 401 recovery path into a second charge.
        _attachIdempotency(retryHeaders, idempotencyKey);
        response = await _withTimeout(request(retryHeaders), timeout);
      }

      if (response.statusCode == 401) {
        await _authService.signOut();
        throw const SessionExpiredException();
      }
    }

    return response;
  }

  /// SEC-0.1. The header carries the opaque Google-signed token and nothing
  /// else - no boolean, no parsed field, no client opinion. Absent header
  /// means "no token available", which is a decision for SEC-0.2 to make.
  static void _attachIntegrity(Map<String, String> headers, String? token) {
    if (token != null && token.isNotEmpty) {
      headers[integrityHeader] = token;
    }
  }

  /// Sprint 2 / B-5. Absent key means the request behaves exactly as it always
  /// did - the backend middleware no-ops without the header - so this is safe
  /// to leave off the many read endpoints that cannot double-charge anything.
  static void _attachIdempotency(Map<String, String> headers, String? key) {
    if (key != null && key.isNotEmpty) {
      headers[idempotencyHeader] = key;
    }
  }

  Future<http.Response> _withTimeout(
    Future<http.Response> future,
    Duration timeout,
  ) {
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Request timed out after ${timeout.inSeconds}s',
      ),
    );
  }
}
