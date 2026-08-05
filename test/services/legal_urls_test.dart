// Sprint 1 / B-2 — LegalUrls.
//
// These URLs are what get typed into the Play Console and App Store Connect,
// so a malformed one is not a bug the user reports, it is a submission that
// bounces days later. They are cheap to assert and expensive to get wrong.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/services/legal_urls.dart';

void main() {
  group('when dotenv was never initialised', () {
    setUp(() {
      // Exactly the state a build lands in when the .env asset is missing:
      // main() catches the failed load and carries on, leaving dotenv
      // uninitialised. Reading it throws.
      dotenv.clean();
    });

    test('reports itself unconfigured instead of throwing', () {
      // The regression this guards: an uncaught NotInitializedError here
      // crashes the BUILD of the profile and paywall screens, turning a
      // missing config file into an unusable app.
      expect(() => LegalUrls.isConfigured, returnsNormally);
      expect(LegalUrls.isConfigured, isFalse);
    });

    test('every accessor is still safe to read', () {
      expect(() => LegalUrls.privacyPolicy, returnsNormally);
      expect(() => LegalUrls.termsOfService, returnsNormally);
      expect(() => LegalUrls.accountDeletion, returnsNormally);
      expect(() => LegalUrls.index, returnsNormally);
    });
  });

  group('when BACKEND_URL is set', () {
    setUp(() {
      dotenv.clean();
      dotenv.loadFromString(envString: 'BACKEND_URL=https://api.example.com');
    });

    test('is configured', () {
      expect(LegalUrls.isConfigured, isTrue);
    });

    test('builds the three store-facing URLs', () {
      expect(LegalUrls.privacyPolicy,
          'https://api.example.com/legal/privacy-policy.html');
      expect(LegalUrls.termsOfService,
          'https://api.example.com/legal/terms-of-service.html');
      expect(LegalUrls.accountDeletion,
          'https://api.example.com/legal/account-deletion.html');
      expect(LegalUrls.index, 'https://api.example.com/legal/');
    });

    test('every URL parses and is absolute', () {
      for (final url in [
        LegalUrls.privacyPolicy,
        LegalUrls.termsOfService,
        LegalUrls.accountDeletion,
      ]) {
        final uri = Uri.parse(url);
        expect(uri.hasScheme, isTrue, reason: '$url must be absolute');
        expect(uri.scheme, 'https');
        expect(uri.host, isNotEmpty);
      }
    });
  });

  group('base URL normalisation', () {
    test('a trailing slash does not produce a doubled slash', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'BACKEND_URL=https://api.example.com/');

      // `//legal/` is normalised by some proxies and 404s on others, which is
      // the worst kind of bug: it works in testing and fails in review.
      expect(LegalUrls.privacyPolicy,
          'https://api.example.com/legal/privacy-policy.html');
      expect(LegalUrls.privacyPolicy, isNot(contains('//legal')));
    });

    test('surrounding whitespace in the env value is ignored', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'BACKEND_URL=  https://api.example.com  ');

      expect(LegalUrls.privacyPolicy,
          'https://api.example.com/legal/privacy-policy.html');
    });

    test('an empty BACKEND_URL reports unconfigured', () {
      dotenv.clean();
      dotenv.loadFromString(envString: 'BACKEND_URL=');

      expect(LegalUrls.isConfigured, isFalse);
    });
  });
}
