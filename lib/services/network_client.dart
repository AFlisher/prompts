import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

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
  Future<http.Response> send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    required Duration timeout,
  }) async {
    final initialHeaders = await headers();
    var response = await _withTimeout(request(initialHeaders), timeout);

    if (response.statusCode == 401) {
      final refreshed =
          await _authService.ensureValidSession(forceRefresh: true);
      if (refreshed) {
        final retryHeaders = await headers();
        response = await _withTimeout(request(retryHeaders), timeout);
      }

      if (response.statusCode == 401) {
        await _authService.signOut();
        throw const SessionExpiredException();
      }
    }

    return response;
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
