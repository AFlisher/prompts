import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const String _accessTokenKey = 'custom_access_token';
  static const String _refreshTokenKey = 'custom_refresh_token';
  static const String _emailConfirmedAtKey = 'custom_email_confirmed_at';

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Restores session on app startup
  Future<void> initializeSession() async {
    try {
      debugPrint("[AuthService] Initializing startup session...");
      await ensureValidSession();
      debugPrint("[AuthService] Startup session initialization completed.");
    } catch (e) {
      debugPrint("[AuthService] Error initializing startup session: $e");
    }
  }

  /// Sign Up a new user with custom Node.js backend
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    debugPrint("[AuthService] Attempting registration to backend for email: $email");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'fullName': fullName,
      }),
    );

    if (response.statusCode != 201) {
      final data = json.decode(response.body);
      debugPrint("[AuthService] Registration failed: ${data['message']}");
      throw AuthException(data['message'] ?? 'Failed to register.');
    }

    debugPrint("[AuthService] Registration successful.");
    return AuthResponse(session: null, user: null);
  }

  /// Sign In with custom Node.js backend and inject token to Supabase client
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint("[AuthService] Attempting login to backend for email: $email");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    final data = json.decode(response.body);
    debugPrint("[AuthService] Login response received. Status: ${response.statusCode}");
    
    if (response.statusCode != 200) {
      debugPrint("[AuthService] Login failed: ${data['message']}");
      throw AuthException(data['message'] ?? 'Failed to sign in.');
    }

    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    
    String? emailConfirmedAt;
    if (data['user'] != null && data['user']['emailConfirmedAt'] != null) {
      emailConfirmedAt = data['user']['emailConfirmedAt'] as String;
    }
    
    debugPrint("[AuthService] Login credentials validated. emailConfirmedAt: $emailConfirmedAt");

    // Save tokens in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    if (emailConfirmedAt != null) {
      await prefs.setString(_emailConfirmedAtKey, emailConfirmedAt);
    }
    debugPrint("[AuthService] Token Save Complete. Saved custom_access_token, custom_refresh_token, and emailConfirmedAt to SharedPreferences.");

    // Inject custom JWT into Supabase client to restore session locally
    final authRes = await _injectSession(accessToken, emailConfirmedAt: emailConfirmedAt);
    return authRes;
  }

  /// Sign In with Google via custom backend — verifies idToken server-side and issues custom JWTs
  Future<AuthResponse> signInWithGoogle(String idToken) async {
    debugPrint("[AuthService] Sending Google idToken to backend for verification...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'idToken': idToken}),
    );

    final data = json.decode(response.body);
    debugPrint("[AuthService] Google sign-in response received. Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("[AuthService] Google sign-in failed: ${data['message']}");
      throw AuthException(data['message'] ?? 'Google sign-in failed.');
    }

    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    String? emailConfirmedAt;
    if (data['user'] != null && data['user']['emailConfirmedAt'] != null) {
      emailConfirmedAt = data['user']['emailConfirmedAt'] as String;
    }

    debugPrint("[AuthService] Google sign-in validated. emailConfirmedAt: $emailConfirmedAt");

    // Save tokens — identical to email login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    if (emailConfirmedAt != null) {
      await prefs.setString(_emailConfirmedAtKey, emailConfirmedAt);
    }
    debugPrint("[AuthService] Google sign-in tokens saved to SharedPreferences.");

    // Inject custom JWT into Supabase client locally — same as email login
    final authRes = await _injectSession(accessToken, emailConfirmedAt: emailConfirmedAt);
    return authRes;
  }

  /// Refreshes the access token using the refresh token
  Future<void> refreshSession(String refreshToken) async {
    debugPrint("[AuthService] Token Refresh Attempt. Sending refresh request to backend...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'refreshToken': refreshToken,
      }),
    );

    final data = json.decode(response.body);
    debugPrint("[AuthService] Refresh response status: ${response.statusCode}");
    
    if (response.statusCode != 200) {
      debugPrint("[AuthService] Token Refresh FAILED: ${data['message']}");
      throw AuthException(data['message'] ?? 'Failed to refresh token.');
    }

    final newAccessToken = data['accessToken'] as String;
    final newRefreshToken = data['refreshToken'] as String;

    // Save new tokens
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, newAccessToken);
    await prefs.setString(_refreshTokenKey, newRefreshToken);
    debugPrint("[AuthService] Token Save Complete (after refresh). Updated tokens saved in SharedPreferences.");

    // Update Supabase Client session locally
    await _injectSession(newAccessToken);
  }

  /// Ensures current session is valid; auto-refreshes if access token is expired.
  /// Returns true if the session is successfully verified and restored locally.
  Future<bool> ensureValidSession() async {
    debugPrint("[AuthService] Calling ensureValidSession()...");
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);

    debugPrint("[AuthService] Token Load Complete. Loaded custom_access_token exists: ${accessToken != null}, custom_refresh_token exists: ${refreshToken != null}");

    if (accessToken == null) {
      debugPrint("[AuthService] No custom access token found. Skipping session validation.");
      return false;
    }

    if (_isTokenExpired(accessToken)) {
      debugPrint("[AuthService] Access token is expired. Refresh required.");
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await refreshSession(refreshToken);
          return currentUser != null;
        } catch (e) {
          debugPrint("[AuthService] Auto-refresh session failed: $e. Signing out user.");
          await signOut();
          return false;
        }
      } else {
        debugPrint("[AuthService] Access token is expired but no refresh token exists. Signing out user.");
        await signOut();
        return false;
      }
    } else {
      debugPrint("[AuthService] Access token is still valid. No refresh required.");
      // Ensure the session is injected into Supabase client locally
      try {
        await _injectSession(accessToken);
        return currentUser != null;
      } catch (e) {
        debugPrint("[AuthService] Error recovering Supabase session: $e. Signing out user.");
        await signOut();
        return false;
      }
    }
  }

  /// In-app Change Password for authenticated users
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    debugPrint("[AuthService] Attempting to change password...");
    
    // Ensure we have a valid session (refreshes the token if it was expired!)
    await ensureValidSession();

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);

    if (accessToken == null) {
      throw AuthException("User is not authenticated.");
    }

    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final data = json.decode(response.body);
    debugPrint("[AuthService] Change password response received. Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("[AuthService] Change password failed: ${data['message']}");
      throw AuthException(data['message'] ?? 'Failed to change password.');
    }

    debugPrint("[AuthService] Password changed successfully.");
  }

  /// Sign Out
  Future<void> signOut() async {
    debugPrint("[AuthService] Signing out. Clearing saved tokens from SharedPreferences...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_emailConfirmedAtKey);
    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint("[AuthService] Supabase client signed out.");
    } catch (_) {}
  }

  /// Polls verification status from custom backend
  Future<bool> checkVerificationStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/auth/status?email=${Uri.encodeComponent(email)}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['verified'] as bool? ?? false;
      }
    } catch (e) {
      debugPrint("Error checking verification status: $e");
    }
    return false;
  }

  /// Requests a password reset link
  Future<void> forgotPassword(String email) async {
    debugPrint("[AuthService] Requesting forgot password reset link for: $email");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
      }),
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw AuthException(data['message'] ?? 'Failed to send reset link.');
    }
    debugPrint("[AuthService] Forgot password reset link email request sent successfully.");
  }

  /// Resends the email verification link
  Future<void> resendVerification(String email) async {
    debugPrint("[AuthService] Requesting email verification link resend for: $email");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/resend-verification'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
      }),
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw AuthException(data['message'] ?? 'Failed to resend verification.');
    }
    debugPrint("[AuthService] Email verification link resend request completed.");
  }

  // Parse JWT payload base64url decoding
  Map<String, dynamic> _parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token format');
    }
    final payload = parts[1];
    var normalized = base64Url.normalize(payload);
    final resp = utf8.decode(base64Url.decode(normalized));
    return json.decode(resp) as Map<String, dynamic>;
  }

  // Helper to determine if a token is expired
  bool _isTokenExpired(String token) {
    try {
      final payload = _parseJwt(token);
      final exp = payload['exp'] as int;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Expired if less than 5 minutes remain
      return DateTime.now().isAfter(expiryDate.subtract(const Duration(minutes: 5)));
    } catch (_) {
      return true;
    }
  }

  /// Locally injects the custom JWT session into the Supabase Client without GoTrue network verification
  Future<AuthResponse> _injectSession(String accessToken, {String? emailConfirmedAt}) async {
    debugPrint("[AuthService] Locally recovering session to prevent GoTrue network refresh calls...");
    try {
      final payload = _parseJwt(accessToken);
      final userId = payload['sub'] as String;
      final email = payload['email'] as String;
      final exp = payload['exp'] as int;
      
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresIn = exp - nowSeconds;

      String? confirmedAt = emailConfirmedAt;
      if (confirmedAt == null) {
        final prefs = await SharedPreferences.getInstance();
        confirmedAt = prefs.getString(_emailConfirmedAtKey);
      }

      final sessionJson = json.encode({
        'access_token': accessToken,
        'refresh_token': 'dummy_refresh_token_to_bypass_gotrue',
        'expires_in': expiresIn > 0 ? expiresIn : 3600,
        'token_type': 'bearer',
        'user': {
          'id': userId,
          'email': email,
          if (confirmedAt != null) 'email_confirmed_at': confirmedAt,
        }
      });

      final authRes = await Supabase.instance.client.auth.recoverSession(sessionJson);
      debugPrint("[AuthService] Session successfully injected locally. Current user: ${authRes.user?.email}");
      return authRes;
    } catch (e) {
      debugPrint("[AuthService] Error in _injectSession: $e");
      rethrow;
    }
  }
}