import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_app/core/services/session_storage.dart';
import 'package:http/http.dart' as http;

/// `invalid` means the server rejected the token (safe to sign out);
/// `networkError` means the request itself failed (offline/timeout/5xx) —
/// the refresh token may still be valid, so don't sign out.
enum SessionRefreshOutcome { success, invalid, networkError }

/// HTTP client for Food Rx backend API. Session tokens live in secure storage.
class ApiClient {
  // Shared so concurrent callers don't each send the single-use refresh
  // token, which would trip the server's reuse detection (refresh_tokens.py).
  static Future<SessionRefreshOutcome>? _refreshFuture;

  /// Fires when an authenticated request receives a 401 and the token refresh
  /// also fails (i.e. the session is truly expired / revoked). Listeners should
  /// treat this as a forced sign-out signal.
  static final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  static Stream<void> get onUnauthorized => _unauthorizedController.stream;

  static String get _baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? '';
    if (url.isEmpty) {
      throw StateError('API_BASE_URL is not set in .env');
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String?> getToken() => SessionStorage.getAccessToken();

  static Future<String?> getRefreshToken() => SessionStorage.getRefreshToken();

  static Future<bool> hasRefreshToken() => SessionStorage.hasRefreshToken();

  static Future<void> setSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
  }) =>
      SessionStorage.setSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        email: email,
      );

  static Future<void> clearSession() => SessionStorage.clearSession();

  static Future<String?> get userId => SessionStorage.getUserId();

  static Future<String?> get userEmail => SessionStorage.getUserEmail();

  static Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static void _throwFromResponse(http.Response response) {
    String message = response.statusCode >= 500
        ? 'Server error. Please try again later.'
        : 'Request failed';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body != null && body['detail'] != null) {
        message = body['detail'] is String
            ? body['detail'] as String
            : body['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(response.statusCode, message);
  }

  /// Exchange refresh token for a new access + refresh pair, distinguishing a
  /// confirmed-invalid token from a request that simply couldn't complete.
  /// Concurrent callers are collapsed onto the same in-flight attempt.
  static Future<SessionRefreshOutcome> refreshSessionDetailed() {
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  /// Convenience wrapper for callers that only care whether the session is
  /// usable again, not why it failed (e.g. a simple retry-once on 401).
  static Future<bool> refreshSession() async =>
      (await refreshSessionDetailed()) == SessionRefreshOutcome.success;

  static Future<SessionRefreshOutcome> _performRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return SessionRefreshOutcome.invalid;
    }

    http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      response = await http.post(
        uri,
        headers: await _headers(includeAuth: false),
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } catch (_) {
      // Couldn't even reach the server — say nothing about the token itself.
      return SessionRefreshOutcome.networkError;
    }

    // 5xx means the server is having a bad time, not that the token is bad.
    if (response.statusCode >= 500) return SessionRefreshOutcome.networkError;
    if (response.statusCode >= 400) return SessionRefreshOutcome.invalid;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final access = body?['access_token'] as String?;
      final refresh = body?['refresh_token'] as String?;
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
        return SessionRefreshOutcome.invalid;
      }

      await SessionStorage.updateTokens(
        accessToken: access,
        refreshToken: refresh,
      );

      final userId = body?['user_id'] as String?;
      final email = body?['email'] as String?;
      if (userId != null && email != null) {
        await SessionStorage.setSession(
          accessToken: access,
          refreshToken: refresh,
          userId: userId,
          email: email,
        );
      }
      return SessionRefreshOutcome.success;
    } catch (_) {
      return SessionRefreshOutcome.networkError;
    }
  }

  static Future<void> revokeRefreshTokenOnLogout() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      final uri = Uri.parse('$_baseUrl/auth/logout');
      await http.post(
        uri,
        headers: await _headers(includeAuth: false),
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } catch (_) {
      // Best effort; local session is cleared regardless.
    }
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool requireAuth,
    bool retried = false,
  }) async {
    final response = await request();
    if (requireAuth && response.statusCode == 401 && !retried) {
      final outcome = await refreshSessionDetailed();
      if (outcome == SessionRefreshOutcome.success) {
        return _send(request, requireAuth: requireAuth, retried: true);
      }
      // Only sign out on a confirmed rejection; a network error during
      // refresh says nothing about the token's validity.
      if (outcome == SessionRefreshOutcome.invalid) {
        _unauthorizedController.add(null);
      }
    }
    return response;
  }

  static Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final response = await _send(
      () async => http.get(uri, headers: await _headers(includeAuth: requireAuth)),
      requireAuth: requireAuth,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> post(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () async => http.post(
        uri,
        headers: await _headers(includeAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      ),
      requireAuth: requireAuth,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> put(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () async => http.put(
        uri,
        headers: await _headers(includeAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      ),
      requireAuth: requireAuth,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> patch(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () async => http.patch(
        uri,
        headers: await _headers(includeAuth: requireAuth),
        body: body != null ? jsonEncode(body) : null,
      ),
      requireAuth: requireAuth,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<void> delete(String path, {bool requireAuth = true}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () async =>
          http.delete(uri, headers: await _headers(includeAuth: requireAuth)),
      requireAuth: requireAuth,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
  }

  static Future<List<int>?> getBytes(String path) async {
    var uri = Uri.parse('$_baseUrl$path');
    final response = await _send(
      () async => http.get(uri, headers: await _headers(includeAuth: true)),
      requireAuth: true,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) _throwFromResponse(response);
    return response.bodyBytes;
  }

  static Future<dynamic> uploadFile(String path, File file,
      {String fieldName = 'file'}) async {
    Future<http.Response> sendRequest() async {
      final uri = Uri.parse('$_baseUrl$path');
      final token = await getToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files
          .add(await http.MultipartFile.fromPath(fieldName, file.path));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }

    var response = await sendRequest();
    if (response.statusCode == 401) {
      final refreshed = await refreshSession();
      if (refreshed) {
        response = await sendRequest();
      }
    }
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
