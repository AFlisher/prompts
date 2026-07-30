// test/screens/profile/edit_profile_avatar_test.dart
//
// R-2 phase 2 — the save flow around the backend avatar upload.
//
// The service-level contract lives in test/services/avatar_upload_test.dart.
// This file covers what the user actually experiences: the loading state, the
// success and failure handling, the profile refresh, and the one behavioural
// change this phase makes to the screen - the client no longer tells the server
// what its own avatar URL is, because the server already decided it.
//
// The picker is faked through ImagePickerPlatform.instance rather than by
// adding a test hook to the screen, so the production widget is exercised
// exactly as shipped.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:prombt_app/data/profile_manager.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/models/profile_model.dart';
import 'package:prombt_app/screens/edit_profile_screen.dart';
import 'package:prombt_app/services/network_client.dart';
import 'package:prombt_app/services/profile_service.dart';

/// Returns a fixed file for any pick, so the screen takes its "an image was
/// chosen" branch. Nothing ever reads the file: the fake service below stands
/// in for the upload.
class _FakePicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return XFile('/tmp/picked-avatar.jpg');
  }
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService({this.uploadError, this.gate});

  final Object? uploadError;

  /// When supplied, the upload does not resolve until the test completes it -
  /// which is the only way to observe the in-flight state. Without it the
  /// future resolves before the first pump and the spinner is never rendered.
  final Completer<void>? gate;

  int uploadCalls = 0;
  int updateCalls = 0;
  bool avatarUrlWasSent = false;
  String? sentFullName;
  String? sentBio;

  @override
  Future<String> uploadAvatar(dynamic file) async {
    uploadCalls++;
    if (gate != null) await gate!.future;
    if (uploadError != null) throw uploadError!;
    return 'https://proj.supabase.co/x/avatars/u1.jpg?v=999';
  }

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? bio,
    bool? personalizationEnabled,
  }) async {
    updateCalls++;
    avatarUrlWasSent = avatarUrl != null;
    sentFullName = fullName;
    sentBio = bio;
    return Profile(
      id: 'u1',
      fullName: fullName,
      bio: bio,
      // The authoritative row already carries whatever the upload stored.
      avatarUrl: 'https://proj.supabase.co/x/avatars/u1.jpg?v=999',
    );
  }
}

Widget _wrap(ProfileManager manager, Widget child) {
  return ProfileProvider(
    notifier: manager,
    child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
  );
}

ProfileManager _managerWithProfile() => ProfileManager()
  ..updateProfile(Profile(id: 'u1', fullName: 'Ahmed', bio: 'hi'));

/// Opens the photo sheet and picks from the gallery, leaving the screen in the
/// "an avatar is pending upload" state.
Future<void> _pickAnAvatar(WidgetTester tester) async {
  // The camera badge sits in a Clip.none stack and can fall outside its
  // parent's hit-test box, so this taps the GestureDetector that owns it.
  await tester.tap(
    find
        .ancestor(
          of: find.byIcon(Icons.camera_alt_rounded),
          matching: find.byType(GestureDetector),
        )
        .first,
  );
  await tester.pumpAndSettle();

  // Asserted, not assumed: if the sheet never opened, every test using this
  // helper would otherwise pass vacuously by simply saving without an avatar.
  expect(find.text('Change Profile Photo'), findsOneWidget,
      reason: 'the photo-source sheet did not open');

  await tester.tap(find.text('Gallery'));
  await tester.pumpAndSettle();
}

/// Scrolls the save button into view before tapping it. Without this the tap
/// silently misses - the button sits below the fold on the default test
/// surface - and every assertion downstream fails for the wrong reason.
Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save Changes'));
}

void main() {
  setUp(() => ImagePickerPlatform.instance = _FakePicker());

  group('a picked avatar is uploaded through the backend', () {
    testWidgets('uploads, then updates the remaining fields', (tester) async {
      final service = _FakeProfileService();
      final manager = _managerWithProfile();

      await tester.pumpWidget(_wrap(
        manager,
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(service.uploadCalls, 1);
      expect(service.updateCalls, 1);
    });

    testWidgets('does not send an avatar URL back to the server', (tester) async {
      // The behavioural change this phase makes. The backend writes
      // profiles.avatar_url itself now, so echoing a URL back would be the
      // client re-asserting a value it no longer decides - and would be the
      // one remaining way for a client to point its avatar at anything.
      final service = _FakeProfileService();

      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(service.avatarUrlWasSent, isFalse);
    });

    testWidgets('refreshes the shared profile with the server row', (tester) async {
      // Single source of truth: every screen showing the avatar reads this.
      final service = _FakeProfileService();
      final manager = _managerWithProfile();

      await tester.pumpWidget(_wrap(
        manager,
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(manager.profile?.avatarUrl, 'https://proj.supabase.co/x/avatars/u1.jpg?v=999');
    });

    testWidgets('the refreshed URL carries the cache-buster, so the image reloads',
        (tester) async {
      final manager = _managerWithProfile();
      final before = manager.profile?.avatarUrl;

      await tester.pumpWidget(_wrap(
        manager,
        EditProfileScreen(isDarkMode: true, profileServiceOverride: _FakeProfileService()),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(manager.profile?.avatarUrl, isNot(equals(before)));
      expect(manager.profile?.avatarUrl, contains('?v='));
    });

    testWidgets('reports success to the user', (tester) async {
      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: _FakeProfileService()),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pump(); // let the snackbar appear before the pop settles

      expect(find.text('Profile updated successfully!'), findsOneWidget);
    });
  });

  group('loading state', () {
    testWidgets('shows a spinner while the upload is in flight and disables save',
        (tester) async {
      final gate = Completer<void>();
      final service = _FakeProfileService(gate: gate);

      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _tapSave(tester);
      await tester.pump(); // one frame: _isSaving is true, upload still gated

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save Changes'), findsNothing);
      // The button's own onPressed is null while saving, so a second tap
      // cannot start a second upload.
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('failure handling', () {
    testWidgets('a rejected image shows the server message and saves nothing',
        (tester) async {
      // The endpoint's 400 messages are user-facing; the screen surfaces them
      // rather than a generic failure.
      final service = _FakeProfileService(
        uploadError: const HttpStatusException(400, 'Animated images cannot be used as an avatar.'),
      );
      final manager = _managerWithProfile();

      await tester.pumpWidget(_wrap(
        manager,
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Animated images cannot be used as an avatar.'),
        findsOneWidget,
      );
      // A failed avatar upload aborts the whole save: name and bio are not
      // written either, so the screen never half-succeeds.
      expect(service.updateCalls, 0);
      expect(manager.profile?.avatarUrl, isNull);
    });

    testWidgets('an expired session is reported and saves nothing', (tester) async {
      final service = _FakeProfileService(uploadError: const SessionExpiredException());

      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Session expired'), findsOneWidget);
      expect(service.updateCalls, 0);
    });

    testWidgets('the save button becomes usable again after a failure', (tester) async {
      // Otherwise a single rejected photo would strand the user on a dead
      // screen with no way to retry.
      final service = _FakeProfileService(uploadError: const HttpStatusException(400, 'nope'));

      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _pickAnAvatar(tester);
      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
    });
  });

  group('saving with no new avatar', () {
    testWidgets('skips the upload entirely', (tester) async {
      // Unchanged behaviour, worth pinning: editing only the name must not
      // touch storage or the avatar endpoint.
      final service = _FakeProfileService();

      await tester.pumpWidget(_wrap(
        _managerWithProfile(),
        EditProfileScreen(isDarkMode: true, profileServiceOverride: service),
      ));
      await tester.pump();

      await _tapSave(tester);
      await tester.pumpAndSettle();

      expect(service.uploadCalls, 0);
      expect(service.updateCalls, 1);
    });
  });
}
