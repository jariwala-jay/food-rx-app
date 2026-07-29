import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';

void main() {
  group('biometricAuthUserMessage', () {
    test('maps user cancel codes to authentication cancelled', () {
      for (final code in ['UserCancelled', 'user_canceled', 'Canceled']) {
        expect(
          biometricAuthUserMessage(PlatformException(code: code)),
          'Authentication cancelled',
        );
      }
    });

    test('maps failed recognition to retry message', () {
      expect(
        biometricAuthUserMessage(PlatformException(code: 'NotAvailable')),
        'Biometric authentication failed. Try again.',
      );
    });
  });
}
