// test/screens/profile/edit_profile_bio_test.dart
//
// The Bio field previously never persisted: the controller was hardcoded
// and the save handler never sent it. It now prefills from the profile
// (single source of truth) and is included in the update payload.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prombt_app/data/profile_manager.dart';
import 'package:prombt_app/main.dart';
import 'package:prombt_app/models/profile_model.dart';
import 'package:prombt_app/screens/edit_profile_screen.dart';
import 'package:prombt_app/services/profile_service.dart';

/// Records the update payload instead of touching secure storage/Supabase.
class _FakeProfileService extends ProfileService {
  String? sentBio;
  String? sentFullName;

  @override
  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? bio,
    bool? personalizationEnabled,
  }) async {
    sentFullName = fullName;
    sentBio = bio;
    return Profile(id: 'u1', fullName: fullName, bio: bio);
  }
}

Widget _wrap(ProfileManager manager, Widget child) {
  return ProfileProvider(
    notifier: manager,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  testWidgets('prefills Bio from the saved profile', (tester) async {
    final manager = ProfileManager()
      ..updateProfile(Profile(
        id: 'u1',
        fullName: 'Ahmed',
        bio: 'Coffee-powered style hunter',
      ));

    await tester.pumpWidget(_wrap(
      manager,
      const EditProfileScreen(isDarkMode: true),
    ));
    await tester.pump();

    expect(find.text('Coffee-powered style hunter'), findsOneWidget);
  });

  testWidgets('falls back to the default bio when none is saved yet', (tester) async {
    final manager = ProfileManager()
      ..updateProfile(Profile(id: 'u1', fullName: 'Ahmed'));

    await tester.pumpWidget(_wrap(
      manager,
      const EditProfileScreen(isDarkMode: true),
    ));
    await tester.pump();

    expect(find.text('AI Style Explorer ✨'), findsOneWidget);
  });

  testWidgets('saving sends the edited bio and refreshes the shared profile', (tester) async {
    final fakeService = _FakeProfileService();
    final manager = ProfileManager()
      ..updateProfile(Profile(id: 'u1', fullName: 'Ahmed', bio: 'Old bio'));

    await tester.pumpWidget(_wrap(
      manager,
      EditProfileScreen(
        isDarkMode: true,
        profileServiceOverride: fakeService,
      ),
    ));
    await tester.pump();

    await tester.enterText(find.text('Old bio'), 'New bio here');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(fakeService.sentBio, 'New bio here');
    // The shared ProfileManager was refreshed, so reopening Edit Profile
    // (or viewing Profile) immediately shows the saved bio.
    expect(manager.profile?.bio, 'New bio here');
  });
}
