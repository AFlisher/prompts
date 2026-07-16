import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
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

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// Prepares authorized headers automatically.
  Future<Map<String, String>> _getHeaders() async {
    try {
      await _authService.ensureValidSession();
    } catch (e) {
      debugPrint("[ApiService] Session check error: $e");
    }

    final accessToken = await _authService.getAccessToken();

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  /// GET /api/categories
  Future<List<Category>> getCategories() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/categories'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load categories. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Category.fromJson(json)).toList();
  }

  /// GET /api/styles
  Future<List<Style>> getStyles() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/styles'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load styles. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/credit-packs
  Future<List<CreditPack>> getCreditPacks() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/credit-packs'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load credit packs. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => CreditPack.fromJson(json)).toList();
  }

  /// GET /api/styles?categoryId=<categoryId>
  Future<List<Style>> getStylesByCategory(String categoryId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/styles?categoryId=$categoryId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load styles for category. Status: ${response.statusCode}');
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
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/styles?trending=true'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load trending styles. Status: ${response.statusCode}');
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
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/styles?recommended=true'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load recommended styles. Status: ${response.statusCode}');
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
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/styles/$styleId/similar?limit=$limit'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load similar styles. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => Style.fromJson(json)).toList();
  }

  /// GET /api/favorites
  Future<List<String>> getFavorites() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/favorites'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load favorites. Status: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return (jsonMap['styleIds'] as List<dynamic>).map((id) => id as String).toList();
  }

  /// POST /api/favorites
  Future<void> addFavorite(String styleId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_backendUrl/api/favorites'),
      headers: headers,
      body: json.encode({'styleId': styleId}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add favorite. Status: ${response.statusCode}');
    }
  }

  /// DELETE /api/favorites/:styleId
  Future<void> removeFavorite(String styleId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_backendUrl/api/favorites/$styleId'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to remove favorite. Status: ${response.statusCode}');
    }
  }

  /// GET /api/notifications
  Future<({List<AppNotification> notifications, int unreadCount})>
      getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/notifications'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications. Status: ${response.statusCode}');
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
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_backendUrl/api/notifications/$id/read'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification read. Status: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return jsonMap['unreadCount'] as int? ?? 0;
  }

  /// GET /api/creations
  Future<List<Map<String, dynamic>>> getCreations() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/creations'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load creations. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((item) => item as Map<String, dynamic>).toList();
  }

  /// DELETE /api/creations/:id
  Future<void> deleteCreation(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_backendUrl/api/creations/$id'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete creation. Status: ${response.statusCode}');
    }
  }

  /// POST /api/creations/migrate - one-time upload of pre-existing local-only
  /// creations (from before backend persistence existed) into the backend.
  /// [creations] is a list of `{styleId, styleName, imageUrl, createdAt}` maps.
  Future<int> migrateCreations(List<Map<String, dynamic>> creations) async {
    if (creations.isEmpty) return 0;

    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_backendUrl/api/creations/migrate'),
      headers: headers,
      body: json.encode({'creations': creations}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to migrate creations. Status: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return jsonMap['migrated'] as int;
  }

  /// POST /api/generate
  Future<String> generateStyleImage(
    String imagePath,
    String styleId, {
    Map<String, dynamic>? fieldValues,
  }) async {
    final headers = await _getHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_backendUrl/api/generate'),
    );

    if (headers.containsKey('Authorization')) {
      request.headers['Authorization'] = headers['Authorization']!;
    }

    request.fields['styleId'] = styleId;
    // Dynamic prompt-template values (if any) travel as a JSON string field.
    // The server validates and substitutes them; the client never builds the
    // final prompt.
    if (fieldValues != null && fieldValues.isNotEmpty) {
      request.fields['fieldValues'] = json.encode(fieldValues);
    }
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
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

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return jsonMap['generatedImageUrl'] as String;
  }
}
