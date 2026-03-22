import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// HTTP client for Food Rx backend API. Uses JWT from SharedPreferences.
class ApiClient {
  static const _keyToken = 'access_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';

  static String get _baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? '';
    if (url.isEmpty) {
      throw StateError('API_BASE_URL is not set in .env');
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> setSession({
    required String accessToken,
    required String userId,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, accessToken);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserEmail, email);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
  }

  static Future<String?> get userId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> get userEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

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

  /// GET request. Returns decoded JSON map or list.
  static Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
    bool requireAuth = true,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    final response = await http.get(
      uri,
      headers: await _headers(includeAuth: requireAuth),
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// POST request. [body] can be Map or List; will be JSON-encoded.
  static Future<dynamic> post(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(
      uri,
      headers: await _headers(includeAuth: requireAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// PUT request.
  static Future<dynamic> put(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.put(
      uri,
      headers: await _headers(includeAuth: requireAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// PATCH request.
  static Future<dynamic> patch(
    String path, {
    dynamic body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.patch(
      uri,
      headers: await _headers(includeAuth: requireAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// DELETE request.
  static Future<void> delete(String path, {bool requireAuth = true}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.delete(
      uri,
      headers: await _headers(includeAuth: requireAuth),
    );
    if (response.statusCode >= 400) _throwFromResponse(response);
  }

  /// GET request returning response bytes (e.g. profile photo).
  static Future<List<int>?> getBytes(String path) async {
    var uri = Uri.parse('$_baseUrl$path');
    final response = await http.get(
      uri,
      headers: await _headers(includeAuth: false),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) _throwFromResponse(response);
    return response.bodyBytes;
  }

  /// Multipart file upload (e.g. profile photo). Returns decoded JSON.
  static Future<dynamic> uploadFile(String path, File file,
      {String fieldName = 'file'}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = await getToken();
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
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
