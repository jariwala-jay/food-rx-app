import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage for auth session tokens and profile identifiers.
class SessionStorage {
  SessionStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUserEmail = 'user_email';
  static const _keyBiometricEnabled = 'biometric_enabled';

  static const _prefKeyLoginCount = 'login_count';
  static const _prefKeyBiometricSuggestionShown = 'biometric_suggestion_shown';

  static const _legacyPrefsToken = 'access_token';
  static const _legacyPrefsUserId = 'user_id';
  static const _legacyPrefsUserEmail = 'user_email';

  static bool _migrated = false;

  static Future<void> _migrateFromSharedPreferencesIfNeeded() async {
    if (_migrated) return;
    _migrated = true;
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_legacyPrefsToken);
    final legacyUserId = prefs.getString(_legacyPrefsUserId);
    final legacyEmail = prefs.getString(_legacyPrefsUserEmail);
    if (legacyToken == null && legacyUserId == null && legacyEmail == null) {
      return;
    }
    final existingRefresh = await _storage.read(key: _keyRefreshToken);
    if (existingRefresh == null && legacyToken != null) {
      await _storage.write(key: _keyAccessToken, value: legacyToken);
    }
    if (legacyUserId != null) {
      await _storage.write(key: _keyUserId, value: legacyUserId);
    }
    if (legacyEmail != null) {
      await _storage.write(key: _keyUserEmail, value: legacyEmail);
    }
    await prefs.remove(_legacyPrefsToken);
    await prefs.remove(_legacyPrefsUserId);
    await prefs.remove(_legacyPrefsUserEmail);
  }

  static Future<String?> getAccessToken() async {
    await _migrateFromSharedPreferencesIfNeeded();
    return _storage.read(key: _keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    await _migrateFromSharedPreferencesIfNeeded();
    return _storage.read(key: _keyRefreshToken);
  }

  static Future<String?> getUserId() async {
    await _migrateFromSharedPreferencesIfNeeded();
    return _storage.read(key: _keyUserId);
  }

  static Future<String?> getUserEmail() async {
    await _migrateFromSharedPreferencesIfNeeded();
    return _storage.read(key: _keyUserEmail);
  }

  static Future<void> setSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserEmail, value: email);
  }

  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsToken);
    await prefs.remove(_legacyPrefsUserId);
    await prefs.remove(_legacyPrefsUserEmail);
  }

  // ── Biometric flag ──────────────────────────────────────────────────────────

  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  // ── Login count + suggestion tracking (non-sensitive, SharedPreferences) ───

  static Future<int> getLoginCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyLoginCount) ?? 0;
  }

  static Future<void> incrementLoginCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_prefKeyLoginCount) ?? 0;
    await prefs.setInt(_prefKeyLoginCount, count + 1);
  }

  static Future<bool> isBiometricSuggestionShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyBiometricSuggestionShown) ?? false;
  }

  static Future<void> markBiometricSuggestionShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyBiometricSuggestionShown, true);
  }

  static Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }
}
