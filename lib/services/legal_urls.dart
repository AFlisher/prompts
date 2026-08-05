import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Sprint 1 / B-2 — the canonical, publicly reachable legal document URLs.
///
/// Both app stores require a privacy policy at a URL a reviewer can open
/// WITHOUT installing the app, and Google Play additionally requires a public
/// account-deletion URL. Until this existed the app rendered its legal text
/// from a Dart constant (`LegalDocuments`), which is unreachable from a
/// browser and therefore satisfies neither store — see the note that used to
/// stand at the top of `legal_document_screen.dart`.
///
/// The documents are served by the backend itself (`/legal/...`), so the base
/// is `BACKEND_URL` rather than a second host that would have to be kept alive
/// and in sync independently. When a marketing domain exists it should redirect
/// to these paths, so the URLs published to the stores keep resolving and there
/// is still exactly one canonical copy of the text.
///
/// Reading `BACKEND_URL` from the same `.env` every other service uses means a
/// staging build automatically points at staging's documents rather than at
/// production's.
abstract class LegalUrls {
  /// Trailing slashes are stripped so `<base>/legal/...` cannot become
  /// `<base>//legal/...`, which some proxies normalise and some 404.
  ///
  /// The try/catch is not defensive padding. `dotenv.env` THROWS
  /// `NotInitializedError` when `load()` was never called or failed, and
  /// `main()` wraps its `dotenv.load` in a catch that only logs — so on a build
  /// whose `.env` asset is missing, dotenv stays uninitialised and every read
  /// of it throws. Without this, that turns a missing config file into a crash
  /// while BUILDING the profile and paywall screens, which is a far worse
  /// failure than the missing link it would be reporting.
  static String get _base {
    String raw;
    try {
      raw = (dotenv.env['BACKEND_URL'] ?? '').trim();
    } catch (_) {
      return '';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// True when a base URL is configured. Callers must check this before
  /// offering a link: an unconfigured build should say the document is
  /// unavailable rather than open `"/legal/privacy-policy.html"` as a
  /// relative path, which resolves to nothing and looks like a broken app.
  static bool get isConfigured => _base.isNotEmpty;

  static String get privacyPolicy => '$_base/legal/privacy-policy.html';
  static String get termsOfService => '$_base/legal/terms-of-service.html';
  static String get accountDeletion => '$_base/legal/account-deletion.html';
  static String get index => '$_base/legal/';
}
