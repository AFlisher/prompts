import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../utils/image_delivery.dart';
import '../utils/image_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'network_client.dart';

/// The exact bytes to upload for an avatar: a re-encoded JPEG with no EXIF.
///
/// R-2. Throws rather than returning anything when the picked file cannot be
/// decoded, and that is the whole point of the function existing.
///
/// It used to be a best-effort step with a fallback that uploaded the original
/// file when decoding failed - which meant the one case where validation
/// mattered was the exact case that skipped it, and skipped SEC-8.3's metadata
/// stripping with it. An avatar that cannot be normalised is refused.
///
/// What this is has changed, and the distinction matters. It used to be the
/// ONLY thing inspecting an avatar's contents, because the upload went straight
/// from the app to Supabase Storage and nothing on the server ever saw the
/// bytes. Since R-2 phase 1 the backend decodes, validates and re-encodes every
/// avatar itself, so this is no longer a security boundary in any sense - it is
/// a compression and early-feedback step, keeping the upload small and telling
/// the user immediately that a photo is unusable rather than after a round
/// trip. The enforceable check is the server's.
@visibleForTesting
Uint8List avatarUploadBytes(Uint8List pickedBytes) {
  final normalized = normalizeImageBytes(pickedBytes, quality: 85);
  if (normalized == null) {
    throw Exception(
      "That photo couldn't be processed. Please choose a different one.",
    );
  }
  return normalized;
}

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

  /// Uploads a new avatar through the backend and returns the URL it stored.
  ///
  /// R-2 phase 2. This used to write to Supabase Storage directly and then set
  /// `profiles.avatar_url` itself. Both now happen server-side, behind
  /// `POST /api/profile/avatar`, which decodes and re-encodes the image before
  /// storing it. There is deliberately no fallback to the old path: a client
  /// that could still reach Storage directly would make the server's
  /// validation optional, which is the whole point of moving it.
  ///
  /// Returns the URL rather than a [Profile] because that is what the endpoint
  /// returns - the caller pairs this with [updateProfile], whose response is
  /// the authoritative row. Synthesising a half-populated [Profile] here would
  /// invent fields nobody asked the server for.
  ///
  /// Errors keep their existing shapes: [SessionExpiredException] once a
  /// refreshed token is still rejected, [TimeoutException] on a stall, and
  /// [HttpStatusException] carrying the server's own user-facing message for a
  /// rejected image ("Animated images cannot be used as an avatar", and so on).
  Future<String> uploadAvatar(File file) async {
    // Only ever used under `flutter test` - see getProfile().
    if (_client == null) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return 'https://example.com/mock-avatar.jpg';
      }
      throw Exception('Profile service is unavailable.');
    }

    // Compression and early feedback, not validation - the server re-decodes
    // and re-encodes whatever arrives. Runs before the request so an unusable
    // photo fails instantly instead of after an upload.
    //
    // No maxDimension: the picker already caps this at 1024 on the way in, and
    // downscaling here would be a behaviour change, not a fix.
    final bytes = avatarUploadBytes(await file.readAsBytes());

    final response = await AuthorizedHttpClient(AuthService()).send(
      (headers) async {
        final streamed = await backendClient.send(buildAvatarRequest(headers, bytes));
        return http.Response.fromStream(streamed);
      },
      timeout: NetworkTimeouts.upload,
    );

    final avatarUrl = avatarUrlFromResponse(response);
    debugPrint('[ProfileService] Avatar uploaded via backend.');
    return avatarUrl;
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


/// Builds the multipart request for one upload attempt.
///
/// Rebuilt per attempt rather than once: a [http.MultipartRequest] can only be
/// sent a single time, so the 401 refresh-and-retry inside
/// [AuthorizedHttpClient.send] needs a fresh one. The bytes are already in
/// memory, so rebuilding re-reads nothing.
@visibleForTesting
http.MultipartRequest buildAvatarRequest(
  Map<String, String> headers,
  Uint8List bytes,
) {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('${backendBaseUrl()}/api/profile/avatar'),
  );

  // This closure copies headers by hand rather than passing the map through,
  // matching how ApiService builds its multipart calls.
  if (headers.containsKey('Authorization')) {
    request.headers['Authorization'] = headers['Authorization']!;
  }

  request.files.add(
    http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: 'avatar.jpg',
      // Explicit, and load-bearing. `http` defaults a part to
      // application/octet-stream, which the backend's multer image filter
      // rejects outright - measured against the real middleware, not assumed.
      // The server does not trust this value for validation; it only has to
      // be plausible enough to clear that first cheap filter.
      contentType: MediaType('image', 'jpeg'),
    ),
  );

  return request;
}

/// Reads the avatar URL out of the endpoint's response, or throws.
///
/// The URL is returned exactly as the server wrote it, cache-buster and all.
/// The `?v=<timestamp>` suffix now originates server-side - the object name
/// never changes, so without it the CDN would keep serving the previous
/// avatar - and rewriting or trimming it here would silently reintroduce that.
@visibleForTesting
String avatarUrlFromResponse(http.Response response) {
  if (response.statusCode != 200) {
    throw HttpStatusException(response.statusCode, _avatarErrorMessage(response));
  }

  final decoded = _tryDecode(response.body);
  final avatarUrl = decoded is Map<String, dynamic> ? decoded['avatarUrl'] : null;
  if (avatarUrl is! String || avatarUrl.isEmpty) {
    throw const HttpStatusException(200, 'Could not update your profile photo.');
  }

  return avatarUrl;
}

/// The server's own message for a rejected avatar, which is written to be shown
/// to a user ("Animated images cannot be used as an avatar."). Falls back to a
/// generic line rather than surfacing a body that might be an HTML error page
/// from something sitting in front of the API.
String _avatarErrorMessage(http.Response response) {
  final decoded = _tryDecode(response.body);
  if (decoded is Map<String, dynamic>) {
    final message = decoded['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return 'Could not update your profile photo.';
}

Object? _tryDecode(String body) {
  try {
    return json.decode(body);
  } catch (_) {
    // Not JSON. Nothing usable, and definitely nothing to show the user.
    return null;
  }
}
