import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'auth_service.dart';
import 'network_client.dart';

/// Submits post-generation feedback (star rating + optional comment) to the
/// backend. Never sends image data - only ids/metrics/text, mirroring the
/// backend's generation_feedback table exactly.
class FeedbackService {
  final AuthService _authService;
  late final AuthorizedHttpClient _client = AuthorizedHttpClient(_authService);

  FeedbackService({AuthService? authService}) : _authService = authService ?? AuthService();

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// POST /api/feedback
  ///
  /// [generationId]/[styleId]/[categoryId]/[generationTimeMs] are the values
  /// the backend returned from the original POST /api/generate call - see
  /// [GenerationResult] - and are round-tripped back here unchanged so the
  /// dashboard can join feedback to the generation it's about.
  Future<void> submitFeedback({
    required int rating,
    String? comment,
    String? generationId,
    String? styleId,
    String? categoryId,
    int? generationTimeMs,
  }) async {
    final appVersion = await _currentAppVersion();

    final response = await _client.send(
      (headers) => http.post(
        Uri.parse('$_backendUrl/api/feedback'),
        headers: headers,
        body: json.encode({
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (generationId != null) 'generationId': generationId,
          if (styleId != null) 'styleId': styleId,
          if (categoryId != null) 'categoryId': categoryId,
          if (generationTimeMs != null) 'generationTimeMs': generationTimeMs,
          if (appVersion != null) 'appVersion': appVersion,
        }),
      ),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 201) {
      throw HttpStatusException(response.statusCode, 'Failed to submit feedback.');
    }
  }

  /// Swallowed on failure (some CI/test environments don't have a real
  /// platform package registry) - appVersion is a nice-to-have on the
  /// feedback payload, never worth failing the submission over.
  Future<String?> _currentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return null;
    }
  }
}
