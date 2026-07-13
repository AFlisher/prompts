import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import 'auth_service.dart';

class WalletService {
  final AuthService _authService = AuthService();

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// Prepares authorized headers automatically.
  Future<Map<String, String>> _getHeaders() async {
    try {
      await _authService.ensureValidSession();
    } catch (e) {
      debugPrint("[WalletService] Session check error: $e");
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

  /// GET /api/wallet
  Future<Wallet> getWallet() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/wallet'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load wallet. Status: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return Wallet.fromJson(jsonMap);
  }

  /// POST /api/wallet/reward - reports that the user watched a rewarded ad.
  Future<AdRewardResult> rewardAd() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_backendUrl/api/wallet/reward'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to record ad reward. Status: ${response.statusCode}');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return AdRewardResult.fromJson(jsonMap);
  }

  /// GET /api/wallet/history - the authenticated user's transaction ledger, newest first.
  Future<List<WalletTransaction>> getWalletHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_backendUrl/api/wallet/history'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load wallet history. Status: ${response.statusCode}');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }
}
