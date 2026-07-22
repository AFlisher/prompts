import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'network_client.dart';
import '../models/category.dart';
import '../models/style.dart';
import '../models/credit_pack.dart';
import '../models/notification_model.dart';

/// Thrown by [ApiService] methods that parse a structured `{code, message}`
/// error body, so callers can branch on `code` instead of matching `message` text.
class ApiException implements Exception {
  final String code;
  final String message;
  ApiException(this.code, this.message);

  @override
  String toString() => message;
}

class ApiService {
  final AuthService _authService = AuthService();
  late final AuthorizedHttpClient _client = AuthorizedHttpClient(_authService);

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// Shared by every generation endpoint that returns a structured
  /// `{code, message}` error body (currently `/api/generate` and
  /// `/api/ai/generate`), so the parsing/fallback logic lives in one place
  /// instead of being copied per provider.
  Never _throwGenerationError(http.Response response) {
    Map<String, dynamic>? body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    throw ApiException(
      (body?['code'] as String?) ?? 'UNKNOWN_ERROR',
      (body?['message'] as String?) ?? 'Failed to generate image. Status: ${response.statusCode}',
    );
  }

  /// GET /api/categories
  Future<List<Category>> getCategories() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/categories'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load categories.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Category.fromJson(json)).toList();
  }

  /// GET /api/styles
  Future<List<Style>> getStyles() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/styles'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load styles.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/credit-packs
  Future<List<CreditPack>> getCreditPacks() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/credit-packs'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load credit packs.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => CreditPack.fromJson(json)).toList();
  }

  /// GET /api/styles?categoryId=<categoryId>
  Future<List<Style>> getStylesByCategory(String categoryId) async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/styles?categoryId=$categoryId'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load styles for category.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/styles?trending=true
  ///
  /// Every enabled style flagged isTrending, regardless of category - powers
  /// the Home screen's dynamic Trending section. There is no dedicated
  /// Trending category; this is a filtered read of the same styles rows
  /// returned by [getStylesByCategory].
  Future<List<Style>> getTrendingStyles() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/styles?trending=true'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load trending styles.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/styles?recommended=true
  ///
  /// Powers the Home screen's "Recommended For You" section. Ranking is
  /// entirely server-side (RecommendationService) - this just returns
  /// whatever the backend decides, including an empty list when
  /// personalization is off or there isn't enough favorite/creation history
  /// yet to personalize from.
  Future<List<Style>> getRecommendedStyles() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/styles?recommended=true'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load recommended styles.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/styles/:id/similar
  ///
  /// Powers Style Details' "You may also like" section - styles similar to
  /// the given anchor style, ranked by RecommendationService. Anonymous-safe
  /// and not gated by the personalization setting, since it's style-to-style
  /// similarity, not the caller's own history.
  Future<List<Style>> getSimilarStyles(String styleId, {int limit = 10}) async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/styles/$styleId/similar?limit=$limit'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load similar styles.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/favorites
  Future<List<String>> getFavorites() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/favorites'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load favorites.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return (jsonMap['styleIds'] as List<dynamic>).map((id) => id as String).toList();
  }

  /// POST /api/favorites
  Future<void> addFavorite(String styleId) async {
    final response = await _client.send(
      (headers) => http.post(
        Uri.parse('$_backendUrl/api/favorites'),
        headers: headers,
        body: json.encode({'styleId': styleId}),
      ),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 201) {
      throw HttpStatusException(response.statusCode, 'Failed to add favorite.');
    }
  }

  /// DELETE /api/favorites/:styleId
  Future<void> removeFavorite(String styleId) async {
    final response = await _client.send(
      (headers) => http.delete(Uri.parse('$_backendUrl/api/favorites/$styleId'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 204) {
      throw HttpStatusException(response.statusCode, 'Failed to remove favorite.');
    }
  }

  /// GET /api/notifications
  Future<({List<AppNotification> notifications, int unreadCount})>
      getNotifications() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/notifications'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load notifications.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    final List<dynamic> list = jsonMap['notifications'] as List<dynamic>? ?? [];
    return (
      notifications: list
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unreadCount: jsonMap['unreadCount'] as int? ?? 0,
    );
  }

  /// POST /api/notifications/:id/read — returns the fresh unread count.
  Future<int> markNotificationRead(String id) async {
    final response = await _client.send(
      (headers) => http.post(Uri.parse('$_backendUrl/api/notifications/$id/read'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to mark notification read.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return jsonMap['unreadCount'] as int? ?? 0;
  }

  /// GET /api/creations
  Future<List<Map<String, dynamic>>> getCreations() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/creations'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load creations.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((item) => item as Map<String, dynamic>).toList();
  }

  /// DELETE /api/creations/:id
  Future<void> deleteCreation(String id) async {
    final response = await _client.send(
      (headers) => http.delete(Uri.parse('$_backendUrl/api/creations/$id'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 204) {
      throw HttpStatusException(response.statusCode, 'Failed to delete creation.');
    }
  }

  /// POST /api/creations/migrate - one-time upload of pre-existing local-only
  /// creations (from before backend persistence existed) into the backend.
  /// [creations] is a list of `{styleId, styleName, imageUrl, createdAt}` maps.
  Future<int> migrateCreations(List<Map<String, dynamic>> creations) async {
    if (creations.isEmpty) return 0;

    final response = await _client.send(
      (headers) => http.post(
        Uri.parse('$_backendUrl/api/creations/migrate'),
        headers: headers,
        body: json.encode({'creations': creations}),
      ),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 201) {
      throw HttpStatusException(response.statusCode, 'Failed to migrate creations.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return jsonMap['migrated'] as int;
  }

  /// POST /api/generate
  ///
  /// [imagePaths] carries every source photo the style collected - one for
  /// classic styles, up to the style's maxImages for multi-image styles. All
  /// parts travel under the same 'file' field name, which the backend accepts
  /// as an array (a single file is just an array of one).
  ///
  /// Returns both the full-resolution original and its server-generated
  /// browsing thumbnail (null if thumbnail generation failed server-side),
  /// plus generationId/categoryId/generationTimeMs - additive fields the
  /// caller round-trips back on the post-generation feedback submission
  /// (POST /api/feedback).
  Future<({
    String imageUrl,
    String? thumbnailUrl,
    String? generationId,
    String? categoryId,
    int? generationTimeMs,
  })> generateStyleImage(
    List<String> imagePaths,
    String styleId, {
    Map<String, dynamic>? fieldValues,
  }) async {
    final response = await _client.send(
      (headers) async {
        // Rebuilt from scratch on every call (including a 401 retry) - a
        // MultipartRequest can only be sent once, but http.MultipartFile.
        // fromPath reads lazily from imagePaths at send time, so rebuilding
        // is safe and re-reads the same local files.
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_backendUrl/api/generate'),
        );

        if (headers.containsKey('Authorization')) {
          request.headers['Authorization'] = headers['Authorization']!;
        }

        request.fields['styleId'] = styleId;
        // Dynamic prompt-template values (if any) travel as a JSON string
        // field. The server validates and substitutes them; the client
        // never builds the final prompt.
        if (fieldValues != null && fieldValues.isNotEmpty) {
          request.fields['fieldValues'] = json.encode(fieldValues);
        }
        for (final imagePath in imagePaths) {
          request.files.add(await http.MultipartFile.fromPath('file', imagePath));
        }

        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      },
      timeout: NetworkTimeouts.upload,
    );

    if (response.statusCode != 200) {
      _throwGenerationError(response);
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return (
      imageUrl: jsonMap['generatedImageUrl'] as String,
      thumbnailUrl: jsonMap['thumbnailUrl'] as String?,
      generationId: jsonMap['generationId'] as String?,
      categoryId: jsonMap['categoryId'] as String?,
      generationTimeMs: jsonMap['generationTimeMs'] as int?,
    );
  }

  /// POST /api/ai/generate
  ///
  /// Text-to-image generation via the Stability AI backend integration -
  /// no source image is sent (the endpoint doesn't accept one); same auth
  /// header and `{code, message}` error-body handling as [generateStyleImage].
  ///
  /// GET /api/styles never sends a style's prompt text to the client (kept
  /// server-side only, same protection /api/generate relies on), so [prompt]
  /// is usually empty for a style-driven generation - pass [styleId] and the
  /// backend resolves the real prompt itself. Supply [prompt] directly only
  /// for free-text generation with no backing style.
  ///
  /// Returns both the full-resolution original and its server-generated
  /// browsing thumbnail (null if thumbnail generation failed server-side).
  Future<({String imageUrl, String? thumbnailUrl})> generateStabilityImage({
    String? prompt,
    String? styleId,
    String? negativePrompt,
    String? aspectRatio,
    String? style,
  }) async {
    final response = await _client.send(
      (headers) => http.post(
        Uri.parse('$_backendUrl/api/ai/generate'),
        headers: headers,
        body: json.encode({
          if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
          if (styleId != null && styleId.isNotEmpty) 'styleId': styleId,
          if (negativePrompt != null && negativePrompt.isNotEmpty) 'negativePrompt': negativePrompt,
          if (aspectRatio != null && aspectRatio.isNotEmpty) 'aspectRatio': aspectRatio,
          if (style != null && style.isNotEmpty) 'style': style,
        }),
      ),
      timeout: NetworkTimeouts.upload,
    );

    if (response.statusCode != 200) {
      _throwGenerationError(response);
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return (
      imageUrl: jsonMap['imageUrl'] as String,
      thumbnailUrl: jsonMap['thumbnailUrl'] as String?,
    );
  }
}
