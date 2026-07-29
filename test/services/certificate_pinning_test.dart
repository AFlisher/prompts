// test/services/certificate_pinning_test.dart
//
// SEC-12.1. These run a real TLS server on localhost with a real (throwaway)
// PKI, so "valid pin", "backup pin", "invalid pin" and "rotated certificate"
// are exercised against an actual handshake rather than a mock. A pinning test
// that never completes a TLS handshake proves nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:prombt_app/services/certificate_pinning.dart';
import 'package:prombt_app/services/network_client.dart';

/// Mirrors what CertificatePinning.initialize builds, but from bytes a test
/// controls. The production path loads the same shape from a bundled asset,
/// which rootBundle cannot serve in a plain unit test.
http.Client pinnedClientFor(List<int> anchorPem) {
  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(anchorPem);
  final httpClient = HttpClient(context: context)
    ..badCertificateCallback = (cert, host, port) => false;
  return IOClient(httpClient);
}

Future<HttpServer> startTlsServer({
  required String certChainPath,
  required String keyPath,
}) async {
  final context = SecurityContext()
    ..useCertificateChain(certChainPath)
    ..usePrivateKey(keyPath);
  final server = await HttpServer.bindSecure('localhost', 0, context);
  server.listen((req) {
    req.response
      ..statusCode = 200
      ..write('ok');
    req.response.close();
  });
  return server;
}

/// Builds a throwaway PKI for the handshake tests.
///
/// Generated at test time and never committed: these are real private keys,
/// this is a public repository, and the SEC-17.2 secret scanner is right to
/// object to checked-in key material even when it is worthless. Returns false
/// if openssl is unavailable, in which case the handshake tests skip rather
/// than fail - they need a real CA to be meaningful at all.
bool generatePki(Directory dir) {
  if (File('${dir.path}/ca_a.pem').existsSync()) return true;
  dir.createSync(recursive: true);

  void run(List<String> args) =>
      Process.runSync('openssl', args, workingDirectory: dir.path);

  try {
    if (Process.runSync('openssl', ['version']).exitCode != 0) return false;
  } catch (_) {
    return false;
  }

  void ca(String name) => run([
        'req', '-x509', '-newkey', 'rsa:2048', '-keyout', '$name.key',
        '-out', '$name.pem', '-days', '3650', '-nodes', '-subj', '/CN=Test $name',
      ]);

  void leaf(String name, String cn, String issuer) {
    run(['req', '-newkey', 'rsa:2048', '-keyout', '$name.key', '-out', '$name.csr',
      '-nodes', '-subj', '/CN=$cn']);
    File('${dir.path}/$name.ext').writeAsStringSync('subjectAltName=DNS:$cn');
    run(['x509', '-req', '-in', '$name.csr', '-CA', '$issuer.pem', '-CAkey', '$issuer.key',
      '-CAcreateserial', '-out', '$name.pem', '-days', '825', '-extfile', '$name.ext']);
    File('${dir.path}/${name}_chain.pem').writeAsStringSync(
      File('${dir.path}/$name.pem').readAsStringSync() +
          File('${dir.path}/$issuer.pem').readAsStringSync(),
    );
  }

  ca('ca_a');
  ca('ca_b');
  leaf('leaf_a', 'localhost', 'ca_a');
  leaf('leaf_a2', 'localhost', 'ca_a');
  leaf('leaf_b', 'localhost', 'ca_b');
  leaf('leaf_wronghost', 'not-localhost.example', 'ca_a');
  File('${dir.path}/ca_both.pem').writeAsStringSync(
    File('${dir.path}/ca_a.pem').readAsStringSync() +
        File('${dir.path}/ca_b.pem').readAsStringSync(),
  );

  return File('${dir.path}/leaf_a_chain.pem').existsSync();
}

void main() {
  final fixtures = Directory('test/fixtures/certs');
  final hasFixtures = generatePki(fixtures);

  group('environment configuration', () {
    test('maps known environments to a bundle', () {
      expect(CertificatePinning.bundlePathFor('prod'), contains('backend_roots.pem'));
      expect(CertificatePinning.bundlePathFor('staging'), contains('.pem'));
    });

    test('an unknown or missing environment falls back to prod, never to off', () {
      // The important half is the second clause: there is no value of
      // PIN_ENVIRONMENT that yields "no pinning".
      for (final env in <String?>[null, '', '  ', 'nonsense', 'DEV', 'production']) {
        final path = CertificatePinning.bundlePathFor(env);
        expect(path, isNotEmpty);
        expect(path, endsWith('.pem'));
      }
    });

    test('is case- and whitespace-tolerant', () {
      expect(CertificatePinning.bundlePathFor('  PROD  '),
          CertificatePinning.bundlePathFor('prod'));
    });
  });

  group('regression against insecure fallback', () {
    test('badCertificateCallback always refuses', () {
      // The single line that could silently undo this whole finding.
      final reject = CertificatePinning.rejectAlways;
      for (final host in ['localhost', 'styliai-backend-production.up.railway.app']) {
        expect(reject(_FakeCert(), host, 443), isFalse);
      }
    });

    test('backendClient throws instead of returning an unpinned client', () {
      CertificatePinning.resetForTest();

      // No silent degradation to http.Client(): a backend call with pinning
      // uninitialised must fail, not travel over the platform trust store.
      expect(() => backendClient, throwsA(isA<SecureConnectionUnavailableException>()));
    });

    test('a pin failure is reported as an ordinary connection error', () {
      // Naming the certificate would tell an attacker their interception was
      // detected, and tell a real user something they cannot act on.
      const generic = "Couldn't connect to the server.";
      expect(friendlyNetworkErrorMessage(const SecureConnectionUnavailableException()), generic);
      expect(friendlyNetworkErrorMessage(const HandshakeException('pin mismatch')), generic);
      expect(friendlyNetworkErrorMessage(const SocketException('down')), generic);
    });

    test('the error message never mentions certificates or pinning', () {
      final msg = friendlyNetworkErrorMessage(const HandshakeException('CERTIFICATE_VERIFY_FAILED'));
      for (final leak in ['certificate', 'pin', 'tls', 'handshake', 'ssl']) {
        expect(msg.toLowerCase(), isNot(contains(leak)));
      }
    });
  });

  group('against a real TLS handshake', () {
    late HttpServer server;

    tearDown(() async {
      try {
        await server.close(force: true);
      } catch (_) {}
    });

    Future<int> statusVia(http.Client client, HttpServer s) async {
      final res = await client
          .get(Uri.parse('https://localhost:${s.port}/'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode;
    }

    test('valid pin: a leaf under the pinned anchor connects', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_a_chain.pem',
        keyPath: '${fixtures.path}/leaf_a.key',
      );
      final client = pinnedClientFor(File('${fixtures.path}/ca_a.pem').readAsBytesSync());

      expect(await statusVia(client, server), 200);
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');

    test('backup pin: a bundle holding two anchors accepts either', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_b_chain.pem',
        keyPath: '${fixtures.path}/leaf_b.key',
      );
      // The bundle carries CA A (current) and CA B (backup); the server
      // presents a leaf under B. This is the rotation case: ship the next
      // anchor before switching to it and nothing breaks on the day.
      final client = pinnedClientFor(File('${fixtures.path}/ca_both.pem').readAsBytesSync());

      expect(await statusVia(client, server), 200);
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');

    test('invalid pin: a leaf under an unpinned CA is refused', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_b_chain.pem',
        keyPath: '${fixtures.path}/leaf_b.key',
      );
      // Pinned to A only; the server presents B. This is the MITM case.
      final client = pinnedClientFor(File('${fixtures.path}/ca_a.pem').readAsBytesSync());

      await expectLater(statusVia(client, server), throwsA(isA<HandshakeException>()));
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');

    test('rotated certificate: a new leaf under the same anchor still connects', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_a2_chain.pem',
        keyPath: '${fixtures.path}/leaf_a2.key',
      );
      // The whole reason this pins roots rather than leaves: the backend's
      // Railway-managed certificate renews about every 90 days with a key we
      // never see. A leaf pin would fail here; a root pin does not.
      final client = pinnedClientFor(File('${fixtures.path}/ca_a.pem').readAsBytesSync());

      expect(await statusVia(client, server), 200);
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');

    test('hostname mismatch is refused even under the pinned anchor', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_wronghost_chain.pem',
        keyPath: '${fixtures.path}/leaf_wronghost.key',
      );
      // Pinning does not replace hostname verification, it narrows the trust
      // set. Both still apply.
      final client = pinnedClientFor(File('${fixtures.path}/ca_a.pem').readAsBytesSync());

      await expectLater(statusVia(client, server), throwsA(isA<HandshakeException>()));
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');

    test('the production anchor bundle rejects a throwaway CA', () async {
      server = await startTlsServer(
        certChainPath: '${fixtures.path}/leaf_a_chain.pem',
        keyPath: '${fixtures.path}/leaf_a.key',
      );
      // The shipped bundle, against a server it must never trust.
      final client = pinnedClientFor(File('assets/certs/backend_roots.pem').readAsBytesSync());

      await expectLater(statusVia(client, server), throwsA(isA<HandshakeException>()));
    }, skip: hasFixtures ? false : 'openssl unavailable - PKI could not be generated');
  });

  group('the shipped anchor bundle', () {
    test('contains exactly the two documented anchors', () {
      final pem = File('assets/certs/backend_roots.pem').readAsStringSync();
      final count = 'BEGIN CERTIFICATE'.allMatches(pem).length;

      // Current + backup. One anchor would mean no rotation headroom; more
      // than two should be a deliberate, reviewed change.
      expect(count, 2);
      expect(pem, contains('ISRG Root X2'));
      expect(pem, contains('Root YE'));
    });

    test('is parseable as a trust anchor set', () {
      // A malformed bundle would make initialize() fail and every backend call
      // fail closed - correct, but catastrophic and silent. Pin it here.
      expect(
        () => SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificatesBytes(
              File('assets/certs/backend_roots.pem').readAsBytesSync()),
        returnsNormally,
      );
    });
  });
}

class _FakeCert implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
