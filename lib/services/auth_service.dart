import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'network_client.dart';

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

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Invoked at the end of every [signOut] - explicit (Profile screen's Sign
  /// Out button), or an internal auto-signout after a failed token refresh
  /// (see [_ensureValidSessionInternal]) or an unverified-email rejection
  /// (LoginScreen). This class has no access to the ChangeNotifier managers
  /// (CreditManager, CreationsManager, etc.) that hold the signed-in
  /// account's credits/gallery/favorites/profile - they live above it in the
  /// widget tree - so main.dart registers a single callback here once, at
  /// startup, that clears all of them. Without this, only whichever call
  /// site happened to remember to clear providers manually would do so,
  /// and every other sign-out path (auto-signout on expiry in particular)
  /// would leave the previous account's data in memory for the next login -
  /// a cross-account privacy leak, not just a UI bug.
  static VoidCallback? onSignedOut;

  String get _backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Reads a token from secure storage, transparently migrating a legacy
  /// plaintext SharedPreferences value on first read so existing sessions
  /// survive the upgrade instead of being silently signed out.
  Future<String?> _readToken(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value != null) return value;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      await _secureStorage.write(key: key, value: legacy);
      await prefs.remove(key);
    }
    return legacy;
  }

  Future<void> _writeToken(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteToken(String key) async {
    await _secureStorage.delete(key: key);
    // Also clear any not-yet-migrated legacy copy.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Retrieves the current access token, if any.
  Future<String?> getAccessToken() => _readToken(_accessTokenKey);

  /// Retrieves the user ID of the currently logged-in user from the JWT custom token.
  Future<String?> getAuthenticatedUserId() async {
    try {
      final accessToken = await _readToken(_accessTokenKey);
      if (accessToken == null) return null;
      final payload = _parseJwt(accessToken);
      return payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

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
    debugPrint("[AuthService] Attempting registration to backend...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'fullName': fullName,
      }),
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Registration request timed out'),
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
    debugPrint("[AuthService] Attempting login to backend...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Sign-in request timed out'),
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

    // Save tokens in secure storage
    await _writeToken(_accessTokenKey, accessToken);
    await _writeToken(_refreshTokenKey, refreshToken);
    if (emailConfirmedAt != null) {
      await _writeToken(_emailConfirmedAtKey, emailConfirmedAt);
    }
    debugPrint("[AuthService] Token Save Complete. Saved custom_access_token, custom_refresh_token, and emailConfirmedAt to secure storage.");

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
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Google sign-in request timed out'),
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
    await _writeToken(_accessTokenKey, accessToken);
    await _writeToken(_refreshTokenKey, refreshToken);
    if (emailConfirmedAt != null) {
      await _writeToken(_emailConfirmedAtKey, emailConfirmedAt);
    }
    debugPrint("[AuthService] Google sign-in tokens saved to secure storage.");

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
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Token refresh request timed out'),
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
    await _writeToken(_accessTokenKey, newAccessToken);
    await _writeToken(_refreshTokenKey, newRefreshToken);
    debugPrint("[AuthService] Token Save Complete (after refresh). Updated tokens saved in secure storage.");

    // Update Supabase Client session locally
    await _injectSession(newAccessToken);
  }

  static Future<bool>? _activeSessionCheck;

  /// Ensures current session is valid; auto-refreshes if access token is
  /// expired. Returns true if the session is successfully verified and
  /// restored locally.
  ///
  /// [forceRefresh] skips the client-side expiry check and always attempts
  /// a refresh via the refresh token - used by [AuthorizedHttpClient] after
  /// a server-returned 401, since the server can reject a token the local
  /// JWT `exp` check still considers valid (e.g. server-side revocation).
  /// A forceRefresh call always runs fresh rather than sharing/polluting the
  /// dedup slot a concurrent plain call might already be using.
  Future<bool> ensureValidSession({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return _ensureValidSessionInternal(forceRefresh: true);
    }

    if (_activeSessionCheck != null) {
      debugPrint("[AuthService] Reusing active ensureValidSession check future.");
      return _activeSessionCheck!;
    }

    final checkFuture = _ensureValidSessionInternal();
    _activeSessionCheck = checkFuture;

    try {
      return await checkFuture;
    } finally {
      _activeSessionCheck = null;
    }
  }

  Future<bool> _ensureValidSessionInternal({bool forceRefresh = false}) async {
    debugPrint("[AuthService] Calling ensureValidSession()...");
    // Two independent keys in secure storage - no shared state between them,
    // so read both concurrently instead of one after another.
    final tokens = await Future.wait([
      _readToken(_accessTokenKey),
      _readToken(_refreshTokenKey),
    ]);
    final accessToken = tokens[0];
    final refreshToken = tokens[1];

    debugPrint("[AuthService] Token Load Complete. Loaded custom_access_token exists: ${accessToken != null}, custom_refresh_token exists: ${refreshToken != null}");

    if (accessToken == null) {
      debugPrint("[AuthService] No custom access token found. Skipping session validation.");
      return false;
    }

    if (forceRefresh || _isTokenExpired(accessToken)) {
      debugPrint("[AuthService] Access token is expired or refresh forced. Refresh required.");
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

    final accessToken = await _readToken(_accessTokenKey);

    if (accessToken == null) {
      throw const AuthException("User is not authenticated.");
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
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Change password request timed out'),
    );

    final data = json.decode(response.body);
    debugPrint("[AuthService] Change password response received. Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("[AuthService] Change password failed: ${data['message']}");
      throw AuthException(data['message'] ?? 'Failed to change password.');
    }

    // The backend rotates the refresh token on password change (revoking all
    // other sessions) and returns a fresh token pair for this one - store it
    // so this session keeps working past the old access token's expiry.
    if (data['accessToken'] is String && data['refreshToken'] is String) {
      await _writeToken(_accessTokenKey, data['accessToken'] as String);
      await _writeToken(_refreshTokenKey, data['refreshToken'] as String);
    }

    debugPrint("[AuthService] Password changed successfully.");
  }

  /// Sign Out
  Future<void> signOut() async {
    debugPrint("[AuthService] Signing out. Clearing saved tokens from secure storage...");
    await _deleteToken(_accessTokenKey);
    await _deleteToken(_refreshTokenKey);
    await _deleteToken(_emailConfirmedAtKey);
    try {
      await Supabase.instance.client.auth.signOut();
      debugPrint("[AuthService] Supabase client signed out.");
    } catch (_) {}

    // Runs even if the Supabase call above threw - the account-scoped
    // providers must be cleared regardless of whether the remote session
    // teardown itself succeeded.
    try {
      onSignedOut?.call();
    } catch (e) {
      debugPrint("[AuthService] onSignedOut callback failed: $e");
    }
  }

  /// Polls verification status from custom backend
  Future<bool> checkVerificationStatus(String email) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/auth/status?email=${Uri.encodeComponent(email)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        NetworkTimeouts.auth,
        onTimeout: () => throw TimeoutException('Verification status check timed out'),
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
    debugPrint("[AuthService] Requesting forgot password reset link...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
      }),
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Forgot password request timed out'),
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw AuthException(data['message'] ?? 'Failed to send reset link.');
    }
    debugPrint("[AuthService] Forgot password reset link email request sent successfully.");
  }

  /// Resends the email verification link
  Future<void> resendVerification(String email) async {
    debugPrint("[AuthService] Requesting email verification link resend...");
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/resend-verification'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
      }),
    ).timeout(
      NetworkTimeouts.auth,
      onTimeout: () => throw TimeoutException('Resend verification request timed out'),
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
      confirmedAt ??= await _readToken(_emailConfirmedAtKey);

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
      debugPrint("[AuthService] Session successfully injected locally.");
      return authRes;
    } catch (e) {
      debugPrint("[AuthService] Error in _injectSession: $e");
      rethrow;
    }
  }
}