import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import 'auth_service.dart';
import 'network_client.dart';

class WalletService {
  final AuthService _authService = AuthService();
  late final AuthorizedHttpClient _client = AuthorizedHttpClient(_authService);

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// GET /api/wallet
  Future<Wallet> getWallet() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/wallet'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load wallet.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return Wallet.fromJson(jsonMap);
  }

  /// POST /api/wallet/reward - reports that the user watched a rewarded ad.
  Future<AdRewardResult> rewardAd() async {
    final response = await _client.send(
      (headers) => http.post(Uri.parse('$_backendUrl/api/wallet/reward'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to record ad reward.');
    }

    final Map<String, dynamic> jsonMap = json.decode(response.body);
    return AdRewardResult.fromJson(jsonMap);
  }

  /// GET /api/wallet/history - the authenticated user's transaction ledger, newest first.
  Future<List<WalletTransaction>> getWalletHistory() async {
    final response = await _client.send(
      (headers) => http.get(Uri.parse('$_backendUrl/api/wallet/history'), headers: headers),
      timeout: NetworkTimeouts.api,
    );

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode, 'Failed to load wallet history.');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }
}
