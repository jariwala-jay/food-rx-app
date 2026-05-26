import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Optional saved login (email + password) for biometric re-auth on this device.
class CredentialStorage {
  CredentialStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyEmail = 'saved_login_email';
  static const _keyPassword = 'saved_login_password';

  static Future<bool> hasSavedCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: email.trim().toLowerCase());
    await _storage.write(key: _keyPassword, value: password);
  }

  static Future<({String email, String password})?> readCredentials() async {
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }
}
