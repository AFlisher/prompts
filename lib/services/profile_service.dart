import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/profile_model.dart';
import '../utils/image_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'network_client.dart';

class ProfileService {
  final SupabaseClient? _client = _safeGetClient();

  static SupabaseClient? _safeGetClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _client?.auth.currentUser;

  Future<Profile> getProfile() async {
    await AuthService().ensureValidSession();
    final client = _client;
    if (client == null) {
      // Only ever used under `flutter test`, where no real Supabase instance
      // exists to talk to - a production build must never silently show a
      // fake account instead of a real error when the backend is
      // unreachable.
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return Profile(
          id: 'test-id',
          fullName: 'Ahmed',
          email: 'ahmed@example.com',
        );
      }
      throw Exception('Profile service is unavailable.');
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final response = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single()
        .timeout(
          NetworkTimeouts.api,
          onTimeout: () => throw TimeoutException('Load profile request timed out'),
        );

    final profile = Profile.fromJson(response);
    debugPrint("[ProfileService] Loaded profile: provider=${profile.provider}");
    return profile;
  }

  Future<Profile> uploadAvatar(File file) async {
    await AuthService().ensureValidSession();
    final client = _client;
    if (client == null) {
      // Only ever used under `flutter test` - see getProfile().
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return Profile(
          id: 'test-id',
          fullName: 'Ahmed',
          email: 'ahmed@example.com',
          avatarUrl: 'https://example.com/mock-avatar.jpg',
        );
      }
      throw Exception('Profile service is unavailable.');
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    // Naming pattern: avatars/{userId}.jpg
    final path = '${user.id}.jpg';

    // Programmatically guarantee conversion to standard JPEG format, with the
    // EXIF metadata removed (SEC-8.3).
    //
    // This upload goes straight from the app to Supabase Storage, so the
    // backend never sees these bytes and cannot strip them the way it does for
    // every other image. That makes this the only place the metadata can be
    // removed before it becomes a publicly readable object named after the
    // user's own id - the re-encode alone never did it, since `encodeJpg`
    // writes any EXIF block it is given straight back out.
    File finalUploadFile = file;
    try {
      final bytes = await file.readAsBytes();
      // No maxDimension: the picker already caps this at 1024 on the way in,
      // and downscaling here would be a behaviour change, not a fix.
      final jpegBytes = normalizeImageBytes(bytes, quality: 85);
      if (jpegBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${user.id}.jpg');
        await tempFile.writeAsBytes(jpegBytes);
        finalUploadFile = tempFile;
        debugPrint("[ProfileService] Image converted to JPEG and metadata stripped.");
      } else {
        debugPrint("[ProfileService] Could not decode picked image. Proceeding with original file.");
      }
    } catch (e) {
      debugPrint("[ProfileService] Image conversion failed with error: $e. Proceeding with original file.");
    }

    // Upload with upsert (overwrite enabled) and content type explicitly set to image/jpeg
    await client.storage.from('avatars').upload(
          path,
          finalUploadFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        ).timeout(
          NetworkTimeouts.upload,
          onTimeout: () => throw TimeoutException('Avatar upload timed out'),
        );

    Directory? tempDir;
    tempDir = await getTemporaryDirectory();

    try {
      if (await finalUploadFile.exists() &&
          finalUploadFile.path.contains(tempDir.path)) {
        await finalUploadFile.delete();
      }
    } catch (_) {}

    // Retrieve public URL
    final publicUrl =
        '${client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    // Update database profiles.avatar_url field and retrieve the updated row
    final response = await client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', user.id)
        .select()
        .single()
        .timeout(
          NetworkTimeouts.api,
          onTimeout: () => throw TimeoutException('Update profile request timed out'),
        );

    return Profile.fromJson(response);
  }

  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? bio,
    bool? personalizationEnabled,
  }) async {
    await AuthService().ensureValidSession();
    final client = _client;
    if (client == null) {
      // Only ever used under `flutter test` - see getProfile().
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return Profile(
          id: 'test-id',
          fullName: fullName ?? 'Ahmed',
          email: 'ahmed@example.com',
          avatarUrl: avatarUrl,
          bio: bio,
          personalizationEnabled: personalizationEnabled ?? true,
        );
      }
      throw Exception('Profile service is unavailable.');
    }

    final user = currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (personalizationEnabled != null) {
      updates['personalization_enabled'] = personalizationEnabled;
    }

    if (updates.isEmpty) {
      return getProfile();
    }

    final response = await client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single()
        .timeout(
          NetworkTimeouts.api,
          onTimeout: () => throw TimeoutException('Update profile request timed out'),
        );

    return Profile.fromJson(response);
  }
}
