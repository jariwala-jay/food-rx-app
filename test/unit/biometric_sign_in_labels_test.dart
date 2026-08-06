import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/auth/biometric_sign_in_labels.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  group('resolveBiometricSignInLabelsFromCapabilities', () {
    test('uses Face ID wording and icon when only face is available', () {
      final labels = resolveBiometricSignInLabelsFromCapabilities(
        availableTypes: const [BiometricType.face],
        isDeviceSupported: true,
      );

      expect(labels.methodName, 'Face ID');
      expect(labels.continueButton, 'Continue with Face ID');
      expect(labels.saveLoginCheckbox, contains('Face ID'));
      expect(labels.disableRow, contains('Face ID'));
      expect(labels.continueIcon, Icons.face);
    });

    test('uses fingerprint wording and icon when only fingerprint is available', () {
      final labels = resolveBiometricSignInLabelsFromCapabilities(
        availableTypes: const [BiometricType.fingerprint],
        isDeviceSupported: true,
      );

      expect(labels.methodName, 'fingerprint');
      expect(labels.continueButton, 'Continue with Fingerprint');
      expect(labels.saveLoginCheckbox, contains('fingerprint'));
      expect(labels.disableRow, contains('fingerprint'));
      expect(labels.continueIcon, Icons.fingerprint);
    });

    test('uses combined wording when face and fingerprint are available', () {
      final labels = resolveBiometricSignInLabelsFromCapabilities(
        availableTypes: const [BiometricType.face, BiometricType.fingerprint],
        isDeviceSupported: true,
      );

      expect(labels.methodName, 'Face ID or fingerprint');
      expect(labels.continueButton, 'Continue with Face ID or fingerprint');
      expect(labels.saveLoginCheckbox, contains('Face ID or fingerprint'));
      expect(labels.continueIcon, Icons.fingerprint);
    });

    test('falls back to device passcode when supported without biometrics', () {
      final labels = resolveBiometricSignInLabelsFromCapabilities(
        availableTypes: const [],
        isDeviceSupported: true,
      );

      expect(labels.methodName, 'device passcode');
      expect(labels.continueButton, 'Continue with Device passcode');
      expect(labels.saveLoginCheckbox, contains('device passcode'));
      expect(labels.continueIcon, Icons.lock_outline);
    });

    test('falls back to device unlock when unsupported', () {
      final labels = resolveBiometricSignInLabelsFromCapabilities(
        availableTypes: const [],
        isDeviceSupported: false,
      );

      expect(labels.methodName, 'device unlock');
      expect(labels.continueButton, 'Continue with Device unlock');
      expect(labels.saveLoginCheckbox, contains('device unlock'));
      expect(labels.continueIcon, Icons.lock_outline);
    });
  });
}
