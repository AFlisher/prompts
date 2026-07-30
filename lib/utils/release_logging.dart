import 'package:flutter/foundation.dart';

/// Phase 6 — stop debug logging from reaching a production build.
///
/// The trap this closes: `debugPrint` is NOT stripped in release. Its name
/// suggests otherwise, and the whole codebase is written as though it were -
/// there are ~100 calls, 44 of them in `auth_service.dart` alone, narrating
/// session refreshes and sign-in flow. All of it goes to logcat on a real
/// device, where any installed app with READ_LOGS, an attached adb session, or
/// a bug-report dump can read it.
///
/// What gets silenced is deliberately the *transport*, not the call sites.
/// Rewriting a hundred call sites is a hundred chances to miss one, and the
/// next one someone adds would be unprotected again. Flutter documents
/// `debugPrint` as a reassignable hook precisely so an app can redirect or
/// suppress it wholesale, so one assignment covers everything written so far
/// and everything written later.
///
/// `assert` needs no equivalent: the Dart VM strips assert statements entirely
/// in release, so an assertion message cannot reach a production build however
/// it is written.
void configureReleaseLogging({bool isRelease = kReleaseMode}) {
  if (!isRelease) return;

  // Signature must match Flutter's `debugPrint` typedef exactly, including the
  // named `wrapWidth`, or the assignment does not compile.
  debugPrint = _silentDebugPrint;
}

void _silentDebugPrint(String? message, {int? wrapWidth}) {
  // Intentionally empty. In release the message is discarded before it can
  // reach the platform log.
}
