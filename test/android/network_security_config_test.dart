// test/android/network_security_config_test.dart
//
// SEC-12.2. These are static assertions over the Android resources, which is
// the only meaningful place to test them from Dart - the config is enforced by
// the Android framework and by Flutter's engine loader, neither of which is
// reachable from `flutter test`.
//
// What they protect is the two decisions most likely to be undone by someone
// acting in good faith later: that backend pinning does NOT live here, and that
// the debug cleartext exception can never reach a release build.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _mainPath = 'android/app/src/main/res/xml/network_security_config.xml';
const _debugPath = 'android/app/src/debug/res/xml/network_security_config.xml';
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

XmlDocument load(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  return XmlDocument.parse(file.readAsStringSync());
}

/// Cleartext flag on an element, or null if unset.
bool? cleartext(XmlElement e) {
  final raw = e.getAttribute('cleartextTrafficPermitted');
  return raw == null ? null : raw == 'true';
}

Iterable<XmlElement> domainConfigs(XmlDocument doc) =>
    doc.rootElement.findElements('domain-config');

List<String> domainsOf(XmlElement config) => config
    .findElements('domain')
    .map((d) => d.innerText.trim())
    .toList();

void main() {
  group('production config', () {
    late XmlDocument doc;

    setUp(() => doc = load(_mainPath));

    test('denies cleartext at the base', () {
      final base = doc.rootElement.findElements('base-config').single;

      expect(cleartext(base), isFalse);
    });

    test('repeats the cleartext denial in domain-config, so it reaches Dart', () {
      // Flutter's engine loader parses domain-config and cleartextTrafficPermitted
      // but NOT base-config. A config expressing the rule only at the base would
      // police the native stack and leave every Dart request unpoliced - which
      // is most of the app's traffic.
      final configs = domainConfigs(doc).toList();

      expect(configs, isNotEmpty,
          reason: 'base-config alone does not reach Flutter traffic');
      for (final c in configs) {
        expect(cleartext(c), isFalse);
      }
    });

    test('covers the hosts the app actually talks to', () {
      final all = domainConfigs(doc).expand(domainsOf).toList();

      expect(all, contains('up.railway.app'));
      expect(all, contains('supabase.co'));
    });

    test('trusts system CAs only - never user-installed roots', () {
      final sources = doc
          .findAllElements('certificates')
          .map((c) => c.getAttribute('src'))
          .toList();

      expect(sources, isNotEmpty);
      expect(sources, everyElement('system'));
      expect(sources, isNot(contains('user')));
    });

    test('permits no cleartext anywhere', () {
      final permissive = doc
          .descendants
          .whereType<XmlElement>()
          .where((e) => cleartext(e) == true);

      expect(permissive, isEmpty,
          reason: 'a release build must have no cleartext exception at all');
    });
  });

  group('backend pinning stays in SEC-12.1', () {
    test('neither config declares a pin-set', () {
      // Deliberate, and load-bearing. Flutter's engine does not parse pin-set,
      // so pins here would protect nothing that matters while creating a second
      // rotation obligation that expires silently. If this test ever fails,
      // someone has duplicated SEC-12.1 into a place where it does not work.
      for (final path in [_mainPath, _debugPath]) {
        final doc = load(path);
        expect(doc.findAllElements('pin-set'), isEmpty, reason: '$path declares a pin-set');
        expect(doc.findAllElements('pin'), isEmpty, reason: '$path declares a pin');
      }
    });

    test('the Dart-layer pin is still the one that pins the backend', () {
      // Cross-check so the two findings cannot drift apart unnoticed.
      final pinning = File('lib/services/certificate_pinning.dart').readAsStringSync();

      expect(pinning, contains('withTrustedRoots: false'));
      expect(File('assets/certs/backend_roots.pem').existsSync(), isTrue);
    });
  });

  group('debug config', () {
    late XmlDocument doc;

    setUp(() => doc = load(_debugPath));

    test('still denies cleartext at the base', () {
      expect(cleartext(doc.rootElement.findElements('base-config').single), isFalse);
    });

    test('permits cleartext for loopback only', () {
      final permissive =
          domainConfigs(doc).where((c) => cleartext(c) == true).toList();

      expect(permissive, hasLength(1));
      expect(
        domainsOf(permissive.single)..sort(),
        ['10.0.2.2', '127.0.0.1', 'localhost'],
      );
    });

    test('keeps production hosts ciphertext-only even in debug', () {
      final denied = domainConfigs(doc)
          .where((c) => cleartext(c) == false)
          .expand(domainsOf)
          .toList();

      expect(denied, contains('up.railway.app'));
      expect(denied, contains('supabase.co'));
    });

    test('does not trust user-installed CAs, not even here', () {
      // The classic debug footgun: add user CAs so Charles can read traffic.
      // An interception path that exists in any build is one merge away from
      // not being debug-only, and SEC-12.1 set the precedent of no bypass.
      final sources = doc
          .findAllElements('certificates')
          .map((c) => c.getAttribute('src'))
          .toList();

      expect(sources, isNot(contains('user')));
    });

    test('lives only under src/debug, so it cannot ship', () {
      // Resource merging picks this copy for the debug variant and the main
      // copy for release. If it ever appeared under src/main, the loopback
      // exception would be in production.
      expect(File(_debugPath).existsSync(), isTrue);
      expect(
        File('android/app/src/main/res/xml/network_security_config.xml')
            .readAsStringSync(),
        isNot(contains('10.0.2.2')),
      );
    });

    test('uses a variant resource rather than debug-overrides', () {
      // Flutter's engine does not parse debug-overrides, so that block would
      // silently fail to permit the Dart cleartext it was added for.
      expect(doc.findAllElements('debug-overrides'), isEmpty);
    });
  });

  group('manifest wiring', () {
    test('references the config', () {
      final manifest = load(_manifestPath);
      final app = manifest.findAllElements('application').single;

      expect(app.getAttribute('android:networkSecurityConfig'),
          '@xml/network_security_config');
    });

    test('does not also set usesCleartextTraffic, which the config supersedes', () {
      // Two sources of truth for the same policy is how they end up disagreeing.
      final manifest = load(_manifestPath);
      final app = manifest.findAllElements('application').single;

      expect(app.getAttribute('android:usesCleartextTraffic'), isNull);
    });
  });
}
