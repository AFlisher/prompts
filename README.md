# StyliAI — Mobile App

Flutter client for **StyliAI** (Dart package `prombt_app`), an AI photo-styling app. A user picks one of their photos, chooses a style from the catalog, and the backend returns a styled image that is saved to their creations.

The app is a **presentation layer**. Every credit, authorization and content decision is made server-side — the client is assumed to be compromised and is never the validator.

---

## Features

- **Authentication** — email/password with verification, password reset, Google Sign-In
- **Style catalog** — categories, trending, recommended, similar styles, favorites, search
- **AI generation** — pick a photo, apply a style; multi-image styles where a style defines them
- **Creations gallery** — full-resolution viewing, save to device, share
- **Profile** — avatar upload, name and bio, personalization toggle
- **Credits** — balance, wallet history, rewarded ads, paywall
- **Notifications** — in-app feed
- **Localization** — English and Arabic (RTL)
- **Theming** — light and dark

Not implemented: **in-app purchases** (server-side verification is a prerequisite — tracked as SEC-6.1) and **account deletion** (a Google Play submission requirement — see [`../LEGAL_REQUIREMENTS.md`](../LEGAL_REQUIREMENTS.md)).

---

## Requirements

| | |
|---|---|
| **Flutter** | 3.44.4 stable — developed and tested against this version |
| **Dart SDK** | `>=3.2.0 <4.0.0` per `pubspec.yaml` |
| **Android** | Android Studio + SDK. The only platform currently built. |
| **iOS** | **Never built.** There is no `Podfile` and no signing configuration. Some hardening is explicitly Android-only — see [`RELEASE.md`](RELEASE.md). |

---

## Setup

```bash
cd prompt_app
flutter pub get
```

### `.env` configuration

Configuration is read through `flutter_dotenv` from a **`.env` file at the project root**, which is git-ignored:

```bash
cp .env.example .env
```

| Variable | Purpose |
|---|---|
| `BACKEND_URL` | Base URL of the StyliAI API. Also decides which URLs receive the user's access token — see below. |
| `SUPABASE_URL` | Supabase project URL, used by the Supabase client for `profiles` |
| `SUPABASE_ANON_KEY` | Supabase publishable key. **Not a secret** — publishable by design; RLS protects the data behind it. |

> **`BACKEND_URL` is security-relevant, not merely configuration.** `isBackendImageUrl()` compares a URL's **scheme, host and port** against it to decide whether to attach the bearer token. A prefix match would be unsafe (`https://api.example@evil.com/` is a real trick), so the comparison is on the parsed origin. Set it wrong and authenticated images silently fail to load.

`.env` is loaded in `main()` before `runApp`. It is not a secret store — treat everything in it as visible to anyone who unpacks the APK.

---

## Running the app

```bash
flutter run                # debug, against .env BACKEND_URL
flutter run --release      # release build on a connected device
flutter devices            # list targets
```

The app expects a reachable backend. With none running, sign-in fails with a friendly connection message rather than an error dump — intended behaviour, not a silent failure.

---

## Running tests

```bash
flutter test                            # full suite
flutter test test/services              # one directory
flutter test --plain-name "avatar"      # by name
flutter analyze                         # static analysis
```

**391 tests across 41 files**, all passing (re-run 2026-08-04).

| Directory | Covers |
|---|---|
| `test/services/` | Auth, network client, certificate pinning, generation providers, profile |
| `test/data/` | Managers: creations, credits, favorites, styles, profile |
| `test/widgets/` | Progressive images, style cards, form widgets |
| `test/screens/` | Auth, home, profile, upload, preview, creations |
| `test/utils/` | Image delivery, normalization, release hardening |
| `test/models/` | Model parsing and back-compatibility |
| `test/regression/` | Pinned past defects |
| `test/android/` | Network security config parsing |

Two conventions used throughout, worth following:

- **Vacuity probes.** After writing a test, break the thing it covers and confirm the test fails. Several tests here previously passed with their control removed; each is now documented at the assertion.
- **Test the shipped widget.** Platform behaviour is faked at the platform-interface seam (e.g. `ImagePickerPlatform.instance`) rather than by adding test hooks to production screens.

Full strategy: [`../backend/docs/qa/QA_TEST_PLAN.md`](../backend/docs/qa/QA_TEST_PLAN.md). Latest run: [`../backend/docs/qa/QA_EXECUTION_REPORT.md`](../backend/docs/qa/QA_EXECUTION_REPORT.md).

---

## Folder structure

```
prompt_app/
├── lib/
│   ├── main.dart          Entry: dotenv, Supabase init, release logging, providers
│   ├── screens/    (23)   One file per screen
│   ├── widgets/    (16)   Reusable UI
│   ├── services/   (20)   API, auth, network client, cert pinning, + generation/ (6) providers
│   ├── data/        (6)   ChangeNotifier managers
│   ├── models/      (8)   Models, tolerant of both API and legacy local shapes
│   ├── utils/       (7)   Image delivery, normalization, secure screen, release logging
│   └── theme/       (2)   Design tokens and button styles
├── test/            (41)  See "Running tests"
├── android/               Host app; MainActivity binds the Play Integrity and FLAG_SECURE channels
├── ios/                   Scaffolding only — never built
├── .env                   Git-ignored configuration
└── RELEASE.md             Release build + hardening reference
```

---

## Release process

**Do not build a release with `flutter build` alone.** Obfuscation and symbol splitting are CLI flags, not project settings, so a plain build silently ships an unobfuscated binary that looks identical to a hardened one.

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/<version> \
  --extra-gen-snapshot-options=--strip
```

The third flag is not optional: without it the build warns that unobfuscated DWARF debug information is still shipped inside the APK, which undoes much of what `--obfuscate` is for.

**Archive `build/symbols/<version>` with the release.** It is git-ignored, not reproducible from a later build, and the only way to read a crash report from that build.

Two behaviours that exist **only** in release builds:

- **Debug logging is silenced.** `debugPrint` is *not* stripped by Flutter despite its name; `configureReleaseLogging()` replaces it with a no-op in release, so roughly a hundred log calls — 44 in `auth_service.dart` alone — never reach logcat on a user's device.
- **Sensitive screens block screenshots.** `FLAG_SECURE` is applied per screen on authentication, profile, account and billing surfaces — deliberately **not** app-wide, because screenshotting your own generated image is the product working.

**Full checklist, symbol handling, and the iOS limitations: [`RELEASE.md`](RELEASE.md).**

---

## Client-side security notes

The client enforces nothing on its own behalf, but it holds three controls that are easy to remove by accident:

- **Certificate pinning** (`services/certificate_pinning.dart`) pins backend TLS to ISRG roots and **fails closed** — there is deliberately no fallback to an unpinned client. Pins live here and *only* here: Flutter's engine ignores `pin-set` in the Android network security config, so adding pins there would look like protection and provide none.
- **Credentials are origin-scoped.** The access token is attached only to URLs whose scheme, host and port match `BACKEND_URL` — never to Supabase Storage, a provider CDN, or anything a response happens to contain.
- **Avatar normalization is UX, not validation.** The client re-encodes a picked photo before upload, but the server re-decodes and re-encodes everything regardless. Do not treat the client step as a security boundary.

---

## Related documentation

| Document | Covers |
|---|---|
| [`RELEASE.md`](RELEASE.md) | Release builds, obfuscation, screenshot protection, iOS limits |
| [`../backend/README.md`](../backend/README.md) | The API this app talks to |
| [`../backend/SECURITY_OPERATIONS.md`](../backend/SECURITY_OPERATIONS.md) | Env reference, logging, rate limits, incident response |
| [`../SYSTEM_ARCHITECTURE.md`](../SYSTEM_ARCHITECTURE.md) | System-wide architecture and data flows |
| [`../SECURITY_REPORT.md`](../SECURITY_REPORT.md) | Security audit — findings, evidence, severities |
| [`../LEGAL_REQUIREMENTS.md`](../LEGAL_REQUIREMENTS.md) | Store-submission blockers |
