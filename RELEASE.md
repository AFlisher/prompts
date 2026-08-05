# StyliAI mobile — release build

Operational reference for producing a production Android build. Backend
operations live in `backend/SECURITY_OPERATIONS.md`.

---

## 1. Build commands

Obfuscation and symbol splitting are **CLI flags, not project settings** —
there is no `pubspec.yaml` or Gradle option that turns them on, so a plain
`flutter build appbundle` ships an unobfuscated build that looks identical.
Always build with both:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/<version> \
  --extra-gen-snapshot-options=--strip

flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols/<version> \
  --extra-gen-snapshot-options=--strip
```

`--obfuscate` renames Dart symbols in the compiled binary.
`--split-debug-info` extracts the symbol map so stack traces can be
de-obfuscated later; **it is required for `--obfuscate` to be accepted.**

`--extra-gen-snapshot-options=--strip` is the third flag and it is not
optional in practice. Without it the build emits:

> Warning: The generated ELF library contains unobfuscated DWARF debugging
> information. To avoid this, use --strip to remove it.

That DWARF section undoes much of what `--obfuscate` is for — the symbol
names are renamed, but the debug information describing them is still shipped
inside the APK. Verified: adding the flag removes the warning, the build
succeeds, and the symbol files are still produced for every ABI
(`app.android-arm.symbols`, `-arm64`, `-x64`).

### Keep the symbols

`build/symbols/<version>` is the only way to read a crash report from that
build. It is **not** in the repository (nothing under `build/` is) and it is
**not** reproducible from a later build. Archive it with the release
artifacts. Without it, every obfuscated stack trace is permanently unreadable.

De-obfuscate with:

```bash
flutter symbolize -i <stack_trace.txt> -d build/symbols/<version>/app.android-arm64.symbols
```

---

## 2. Release checklist

**Before building**
- [ ] `android/key.properties` and the keystore are present locally and **untracked**.
- [ ] `android/app/google-services.json` is **not** staged or committed (it carries a live Firebase API key — SEC-17.3; it is gitignored).
- [ ] `.env` contains the production `BACKEND_URL` and `SUPABASE_URL`.
- [ ] `flutter analyze` reports no new issues.
- [ ] `flutter test` passes.

**Build**
- [ ] Built with `--obfuscate --split-debug-info=…` (§1).
- [ ] `build/symbols/<version>` archived with the release.

**Verify the artifact**
- [ ] Install the release build on a device and confirm sign-in, generation, and avatar upload work against production.
- [ ] `adb logcat` while exercising sign-in shows **no** app debug output (see §3).
- [ ] Screenshotting the login and profile screens is blocked; screenshotting a generated image still works (see §4).

**Store submission gates** (Sprint 1 — only for a build going to a store)

Full detail and the console-side steps are in **[`STORE_COMPLIANCE.md`](STORE_COMPLIANCE.md)**.

- [ ] `grep -rn "\[\[PLACEHOLDER" ../backend/public/legal/` returns **nothing**, and all three documents carry a real effective date.
- [ ] Profile → Danger Zone → **Delete Account** exercised end-to-end against a throwaway production account: the account is gone, the app returns to the signed-out screen, and signing in again fails.
- [ ] Privacy screen → Privacy Policy and Terms of Service both open the **hosted** pages in a browser (not the bundled fallback). If they open the in-app reader, `BACKEND_URL` is missing from `.env`.
- [ ] Paywall footer → Terms and Privacy links open the hosted pages.
- [ ] The three `/legal/...` URLs return 200 from a signed-out browser against production.
- [ ] **The simulated purchase flow is not reachable** in this build (B-3). Shipping it violates App Store 3.1.1 and Google Play Payments policy.
- [ ] iOS only: the AdMob App ID and rewarded unit are the real ones, not Google's test IDs (B-6).

---

## 3. Logging in release builds

`configureReleaseLogging()` runs first in `main()` and silences `debugPrint`
when `kReleaseMode` is true.

This matters because **`debugPrint` is not stripped in release** despite its
name. The codebase has roughly a hundred calls — 44 in `auth_service.dart`
alone — narrating session refreshes and sign-in flow. Without this they all
reach logcat on production devices, readable by any app holding `READ_LOGS`,
by an attached adb session, and by a bug-report dump.

The *transport* is silenced rather than the call sites: rewriting a hundred
call sites is a hundred chances to miss one, and the next call someone adds
would be unprotected again. Flutter documents `debugPrint` as a reassignable
hook for exactly this.

`assert` needs no equivalent — the Dart VM strips assert statements entirely
in release, so an assertion message cannot reach a production build however it
is written.

Debug builds are unaffected.

---

## 4. Screenshot protection

`SecureScreenGuard` wraps screens that display credentials, account details or
billing:

`login` · `register` · `forgot_password` · `change_password` · `profile` ·
`edit_profile` · `paywall`

**Android** applies `FLAG_SECURE`, which blocks screenshots and screen
recording *and* blanks the window in the recent-apps switcher. That third
effect is the one most worth having: the task-switcher thumbnail is a
screenshot the user never asked for, never sees taken, and which persists
after they leave the screen.

**Deliberately not app-wide.** Users screenshot their own generated images to
save and share them — that is the product working. Creations, the image
preview, home, upload and style details are asserted by test to stay
screenshot-able.

Protection is reference-counted, so overlapping secure screens (opening Edit
Profile from Profile) cannot leave the flag stuck on or off.

### iOS limitation

iOS has **no equivalent of `FLAG_SECURE`**. There is no supported API that
prevents a screenshot; the platform only reports captures after the fact
(`UIScreen.isCaptured`, `userDidTakeScreenshotNotification`). The common
workaround — a hidden `UITextField` with `isSecureTextEntry` used as a
rendering host — relies on undocumented private-view behaviour and has broken
across iOS releases.

The Dart side calls the channel on iOS anyway; with no host handler it returns
`notImplemented`, which surfaces as `false` and is not an error. If an iOS
host is added later it can implement whatever is then supportable with no Dart
change.

**iOS has never been built for this project** (there is no `Podfile`), so
nothing is claimed about it beyond the above.

---

## 5. Build configuration

`android/app/build.gradle.kts`, `buildTypes.release`:

- `isMinifyEnabled = true` — R8 shrinking and obfuscation of the Java/Kotlin side.
- `proguardFiles(...)` — `proguard-android-optimize.txt` plus local rules.
- `signingConfig` — the release keystore, read from untracked `key.properties`.
- `isDebuggable` is **not** set, so it defaults to `false` for release.

Debug builds are untouched by everything in this document.
