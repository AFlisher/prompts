// test/services/avatar_upload_test.dart
//
// R-2 phase 2 — the client uploads avatars through the backend.
//
// The avatar used to go straight from the app to Supabase Storage, which meant
// the only thing inspecting its contents was code running on the uploader's own
// device. Phase 1 put a validating endpoint in front of storage; this phase is
// what makes the app actually use it, and what removes the direct path so the
// server's validation cannot simply be walked around.
//
// Two of these tests are about request shape rather than behaviour, and they
// earn their place: the part's field name and Content-Type are both load-
// bearing, and getting either wrong fails as a flat 400 with nothing in the
// client to indicate why.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prombt_app/services/network_client.dart';
import 'package:prombt_app/services/profile_service.dart';

void main() {
  final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i % 256));

  group('request construction', () {
    test('posts to the backend avatar endpoint', () {
      final request = buildAvatarRequest(const {}, bytes);

      expect(request.method, 'POST');
      expect(request.url.path, '/api/profile/avatar');
    });

    test('sends the image as a part named "avatar"', () {
      // The backend reads `upload.single("avatar")`. Any other field name is a
      // 400 with an empty req.file and no clue on the client.
      final request = buildAvatarRequest(const {}, bytes);

      expect(request.files, hasLength(1));
      expect(request.files.single.field, 'avatar');
    });

    test('declares the part as image/jpeg, not octet-stream', () {
      // Measured against the real middleware: an application/octet-stream part
      // - which is what `http` sends when contentType is omitted - is rejected
      // outright by multer's image filter. This is the single detail most
      // likely to be "cleaned up" by someone who assumes the default is sane.
      final request = buildAvatarRequest(const {}, bytes);

      expect(request.files.single.contentType.mimeType, 'image/jpeg');
    });

    test('carries the bytes it was given, and a filename', () {
      final request = buildAvatarRequest(const {}, bytes);

      expect(request.files.single.length, bytes.length);
      expect(request.files.single.filename, isNotNull);
    });

    test('forwards the Authorization header from the authorized client', () {
      // Credentials come from AuthorizedHttpClient.headers(), never from a
      // second token path of this feature's own.
      final request = buildAvatarRequest(const {'Authorization': 'Bearer abc'}, bytes);

      expect(request.headers['Authorization'], 'Bearer abc');
    });

    test('sends no Authorization header when there is no session', () {
      // Unauthenticated: the request still goes out and the server answers 401,
      // which AuthorizedHttpClient.send turns into its refresh-then-signout
      // path. The client never invents a credential.
      final request = buildAvatarRequest(const {}, bytes);

      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('builds a fresh request each time, since one can only be sent once', () {
      // The 401 retry inside AuthorizedHttpClient.send re-invokes the builder.
      // Returning a cached request would make the retry throw instead of retry.
      final a = buildAvatarRequest(const {}, bytes);
      final b = buildAvatarRequest(const {}, bytes);

      expect(identical(a, b), isFalse);
    });
  });

  group('successful upload', () {
    test('returns the avatar URL the backend reported', () {
      final response = http.Response(
        json.encode({'avatarUrl': 'https://proj.supabase.co/x/avatars/u1.jpg?v=17'}),
        200,
      );

      expect(
        avatarUrlFromResponse(response),
        'https://proj.supabase.co/x/avatars/u1.jpg?v=17',
      );
    });

    test('preserves the ?v= cache-buster exactly as the server wrote it', () {
      // The object name never changes, so the cache-buster is the only thing
      // that makes a new avatar visible. It now originates server-side;
      // trimming or rewriting it here would silently reintroduce a stale
      // avatar that only a reinstall clears.
      const url = 'https://proj.supabase.co/x/avatars/u1.jpg?v=1784034159601';
      final response = http.Response(json.encode({'avatarUrl': url}), 200);

      final returned = avatarUrlFromResponse(response);

      expect(returned, url);
      expect(returned, contains('?v=1784034159601'));
    });

    test('a changed URL is what refreshes the cached avatar image', () {
      // The image layer keys on the URL, so two uploads must not produce the
      // same address - otherwise the old picture keeps being served.
      final first = avatarUrlFromResponse(
        http.Response(json.encode({'avatarUrl': 'https://x/avatars/u1.jpg?v=1'}), 200),
      );
      final second = avatarUrlFromResponse(
        http.Response(json.encode({'avatarUrl': 'https://x/avatars/u1.jpg?v=2'}), 200),
      );

      expect(first, isNot(equals(second)));
    });
  });

  group('backend validation failure', () {
    test('surfaces the server message for a rejected image', () {
      // The endpoint's 400 messages are written to be shown to a user
      // ("Animated images cannot be used as an avatar."). Replacing them with
      // a generic line would throw away the only explanation there is.
      final response = http.Response(
        json.encode({'message': 'Animated images cannot be used as an avatar.'}),
        400,
      );

      expect(
        () => avatarUrlFromResponse(response),
        throwsA(
          isA<HttpStatusException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Animated images cannot be used as an avatar.'),
        ),
      );
    });

    test('falls back to a generic message when the body is not JSON', () {
      // A proxy or gateway in front of the API can answer with HTML. Echoing
      // that at the user would be meaningless at best.
      final response = http.Response('<html><body>502 Bad Gateway</body></html>', 502);

      late final HttpStatusException error;
      try {
        avatarUrlFromResponse(response);
        fail('expected a throw');
      } on HttpStatusException catch (e) {
        error = e;
      }

      expect(error.statusCode, 502);
      expect(error.message, 'Could not update your profile photo.');
      expect(error.message, isNot(contains('html')));
    });

    test('falls back when the error body carries no message field', () {
      final response = http.Response(json.encode({'code': 'NOPE'}), 400);

      expect(
        () => avatarUrlFromResponse(response),
        throwsA(isA<HttpStatusException>()
            .having((e) => e.message, 'message', 'Could not update your profile photo.')),
      );
    });

    test('rejects a 200 whose body has no avatarUrl', () {
      // A success status with nothing usable in it must not be reported as a
      // successful upload - the caller would then save a null avatar.
      expect(
        () => avatarUrlFromResponse(http.Response(json.encode({'ok': true}), 200)),
        throwsA(isA<HttpStatusException>()),
      );
    });

    test('rejects a 200 with an empty avatarUrl', () {
      expect(
        () => avatarUrlFromResponse(http.Response(json.encode({'avatarUrl': ''}), 200)),
        throwsA(isA<HttpStatusException>()),
      );
    });

    test('rejects a 200 whose body is not JSON at all', () {
      expect(
        () => avatarUrlFromResponse(http.Response('not json', 200)),
        throwsA(isA<HttpStatusException>()),
      );
    });
  });

  group('unauthenticated and expired sessions', () {
    test('a 401 is reported as a session problem, not an image problem', () {
      // In the live path AuthorizedHttpClient.send intercepts a 401 first, does
      // exactly one forced refresh and retry, and throws SessionExpiredException
      // if it is still 401 (pinned in network_client_test.dart). This covers the
      // shape that reaches the caller if a 401 ever arrives here directly.
      final response = http.Response(
        json.encode({'message': 'Invalid or expired access token.'}),
        401,
      );

      expect(
        () => avatarUrlFromResponse(response),
        throwsA(isA<HttpStatusException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('friendlyNetworkErrorMessage maps a session expiry to a sign-in prompt', () {
      expect(
        friendlyNetworkErrorMessage(const SessionExpiredException()),
        'Your session has expired. Please sign in again.',
      );
    });

    test('friendlyNetworkErrorMessage maps a 401 to the same prompt', () {
      expect(
        friendlyNetworkErrorMessage(const HttpStatusException(401, 'nope')),
        'Your session has expired. Please sign in again.',
      );
    });
  });

  group('network failure', () {
    test('a dropped connection maps to a connection message, not a raw error', () {
      expect(
        friendlyNetworkErrorMessage(const SocketException('failed')),
        "Couldn't connect to the server.",
      );
    });

    test('a stalled upload maps to a timeout message', () {
      // There is no cancel control in the avatar flow, so this timeout is what
      // bounds a hung upload. It is the upload budget, not the shorter api one.
      expect(
        friendlyNetworkErrorMessage(TimeoutException('Request timed out')),
        'The request timed out. Please try again.',
      );
      expect(NetworkTimeouts.upload.inSeconds, greaterThan(NetworkTimeouts.api.inSeconds));
    });

    test('a pinning failure is not distinguishable from a connection failure', () {
      // SEC-12.1: telling a user (or an interceptor) that pinning refused is
      // information neither should get.
      expect(
        friendlyNetworkErrorMessage(const SecureConnectionUnavailableException()),
        "Couldn't connect to the server.",
      );
    });

    test('a 500 maps to a generic retry message', () {
      expect(
        friendlyNetworkErrorMessage(const HttpStatusException(500, 'boom')),
        'Something went wrong. Please try again later.',
      );
    });
  });

  group('no direct Storage path remains', () {
    test('the client contains no Supabase Storage calls at all', () {
      // The security property of this phase, asserted against the source rather
      // than against behaviour: as long as the app can still write to Storage
      // itself, the backend's validation is optional for anyone willing to call
      // the SDK directly. Phase 3 removes the RLS policies that would still
      // permit it; this ensures our own code never does.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('storage.from(')) offenders.add(entity.path);
      }

      expect(offenders, isEmpty, reason: 'Supabase Storage is reachable from: $offenders');
    });

    test('profile_service no longer imports the storage temp-file machinery', () {
      // The old path wrote a temp JPEG to disk purely to hand a File to the
      // Storage SDK. Nothing writes avatar bytes to disk any more.
      final source = File('lib/services/profile_service.dart').readAsStringSync();

      expect(source.contains('getTemporaryDirectory'), isFalse);
      expect(source.contains('path_provider'), isFalse);
    });

    test('the upload goes through the shared authorized client', () {
      // Not a second token path of its own: the same client that performs the
      // proactive refresh and the single 401 retry for every other call.
      final source = File('lib/services/profile_service.dart').readAsStringSync();

      expect(source.contains('AuthorizedHttpClient'), isTrue);
      expect(source.contains('backendClient'), isTrue);
    });
  });
}
