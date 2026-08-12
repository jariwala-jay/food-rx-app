import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reads/clears the legacy saved login (email + raw password) written by
/// pre-migration app versions for biometric re-auth. New devices never write
/// to this storage — see AuthController.enableBiometricLogin(), which uses a
/// refresh token instead — so this only exists to detect and migrate
/// installs that still have a plaintext password on disk from before that
/// change (see AuthController.loginWithSavedCredentials()).
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
