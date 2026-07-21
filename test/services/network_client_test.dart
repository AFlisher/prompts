// test/services/network_client_test.dart
//
// Release Candidate QA - networking fixes. Directly verifies the three
// pieces that can't be observed just by reading the code:
//  1. A request that never responds actually times out (throws
//     TimeoutException) instead of hanging forever.
//  2. A 401 triggers exactly one forced refresh + one retry - never more
//     (no duplicate retries, no infinite loop) - and only signs the user
//     out if the retry is *also* unauthorized.
//  3. friendlyNetworkErrorMessage never leaks raw exception text.
//
// AuthService is a concrete (non-final) class with overridable instance
// methods, so a thin subclass stands in for it here instead of touching
// real secure storage/Supabase - this isolates AuthorizedHttpClient's own
// retry/timeout logic from AuthService's internals, which are already
// covered by their own tests.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prombt_app/services/auth_service.dart';
import 'package:prombt_app/services/network_client.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.refreshSucceeds = true});

  final bool refreshSucceeds;
  String token = 'initial-token';
  int ensureValidSessionCalls = 0;
  int forceRefreshCalls = 0;
  int signOutCalls = 0;

  @override
  Future<bool> ensureValidSession({bool forceRefresh = false}) async {
    ensureValidSessionCalls++;
    if (!forceRefresh) return true;

    forceRefreshCalls++;
    if (refreshSucceeds) {
      token = 'refreshed-token';
      return true;
    }
    return false;
  }

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  group('AuthorizedHttpClient - timeout (Task 1)', () {
    test('a request that never responds throws TimeoutException instead of hanging', () async {
      final client = AuthorizedHttpClient(_FakeAuthService());

      expect(
        () => client.send(
          (headers) => Completer<http.Response>().future, // never completes
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('a request that responds in time never times out', () async {
      final client = AuthorizedHttpClient(_FakeAuthService());

      final response = await client.send(
        (headers) async => http.Response('{"ok":true}', 200),
        timeout: const Duration(seconds: 5),
      );

      expect(response.statusCode, 200);
    });
  });

  group('AuthorizedHttpClient - 401 handling (Task 2)', () {
    test('a 401 triggers exactly one forced refresh and one retry, then succeeds', () async {
      final auth = _FakeAuthService(refreshSucceeds: true);
      final client = AuthorizedHttpClient(auth);
      var callCount = 0;

      final response = await client.send(
        (headers) async {
          callCount++;
          if (callCount == 1) return http.Response('unauthorized', 401);
          return http.Response('{"ok":true}', 200);
        },
        timeout: const Duration(seconds: 5),
      );

      expect(response.statusCode, 200);
      expect(callCount, 2, reason: 'exactly one retry - not zero, not more');
      expect(auth.forceRefreshCalls, 1, reason: 'exactly one forced refresh - no duplicate retries');
      expect(auth.signOutCalls, 0, reason: 'the retry succeeded, so the user must not be signed out');
    });

    test('a 401 that persists after the forced refresh signs the user out and stops - no infinite loop', () async {
      final auth = _FakeAuthService(refreshSucceeds: true);
      final client = AuthorizedHttpClient(auth);
      var callCount = 0;

      await expectLater(
        client.send(
          (headers) async {
            callCount++;
            return http.Response('unauthorized', 401); // always 401
          },
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(callCount, 2, reason: 'the request must be attempted exactly twice - never a third time');
      expect(auth.forceRefreshCalls, 1, reason: 'only one forced refresh is ever attempted');
      expect(auth.signOutCalls, 1, reason: 'a still-401 retry must sign the user out exactly once');
    });

    test('a 401 with a failed token refresh never retries and signs out immediately', () async {
      final auth = _FakeAuthService(refreshSucceeds: false);
      final client = AuthorizedHttpClient(auth);
      var callCount = 0;

      await expectLater(
        client.send(
          (headers) async {
            callCount++;
            return http.Response('unauthorized', 401);
          },
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<SessionExpiredException>()),
      );

      expect(callCount, 1, reason: 'a failed refresh must not trigger a retry at all');
      expect(auth.forceRefreshCalls, 1);
      expect(auth.signOutCalls, 1);
    });
  });

  group('friendlyNetworkErrorMessage (Task 3)', () {
    test('maps SessionExpiredException to a session-expired message', () {
      expect(
        friendlyNetworkErrorMessage(const SessionExpiredException()),
        'Your session has expired. Please sign in again.',
      );
    });

    test('maps a 401 HttpStatusException to a session-expired message', () {
      expect(
        friendlyNetworkErrorMessage(const HttpStatusException(401, 'nope')),
        'Your session has expired. Please sign in again.',
      );
    });

    test('maps a 500 HttpStatusException to a generic server-error message', () {
      expect(
        friendlyNetworkErrorMessage(const HttpStatusException(500, 'boom')),
        'Something went wrong. Please try again later.',
      );
    });

    test('maps TimeoutException to a timeout message', () {
      expect(
        friendlyNetworkErrorMessage(TimeoutException('slow')),
        'The request timed out. Please try again.',
      );
    });

    test('maps SocketException to a connectivity message, never the raw exception text', () {
      final message = friendlyNetworkErrorMessage(
        const SocketException('Failed host lookup: xyz (OS Error: No address associated with hostname, errno = 7)'),
      );
      expect(message, "Couldn't connect to the server.");
      expect(message.contains('SocketException'), isFalse);
      expect(message.contains('errno'), isFalse);
    });

    test('maps an unknown error to a generic message, never its raw text', () {
      final message = friendlyNetworkErrorMessage(const FormatException('Unexpected character at 12'));
      expect(message, 'Something unexpected happened.');
      expect(message.contains('FormatException'), isFalse);
      expect(message.contains('Unexpected character'), isFalse);
    });
  });
}
