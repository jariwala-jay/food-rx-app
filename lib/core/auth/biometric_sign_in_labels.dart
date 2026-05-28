import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricSignInLabels {
  const BiometricSignInLabels({
    required this.methodName,
    required this.methodNameTitle,
    required this.saveLoginCheckbox,
    required this.continueButton,
    required this.disableRow,
    required this.disableDialogTitle,
    required this.disableDialogBody,
    required this.disabledSnackbar,
    required this.continueIcon,
  });

  final String methodName;
  final String methodNameTitle;
  final String saveLoginCheckbox;
  final String continueButton;
  final String disableRow;
  final String disableDialogTitle;
  final String disableDialogBody;
  final String disabledSnackbar;
  final IconData continueIcon;
}

Future<BiometricSignInLabels> resolveBiometricSignInLabels(
  LocalAuthentication localAuth,
) async {
  List<BiometricType> types = [];
  var deviceSupported = false;

  try {
    types = await localAuth.getAvailableBiometrics();
    deviceSupported = await localAuth.isDeviceSupported();
  } catch (_) {
    types = [];
    deviceSupported = false;
  }

  return resolveBiometricSignInLabelsFromCapabilities(
    availableTypes: types,
    isDeviceSupported: deviceSupported,
  );
}

BiometricSignInLabels resolveBiometricSignInLabelsFromCapabilities({
  required List<BiometricType> availableTypes,
  required bool isDeviceSupported,
}) {
  final hasFace = availableTypes.contains(BiometricType.face);
  final hasFingerprint = availableTypes.contains(BiometricType.fingerprint) ||
      availableTypes.contains(BiometricType.strong);
  final String methodName;
  final IconData continueIcon;

  if (hasFace && hasFingerprint) {
    methodName = 'Face ID or fingerprint';
    continueIcon = Icons.fingerprint;
  } else if (hasFace) {
    methodName = 'Face ID';
    continueIcon = Icons.face;
  } else if (hasFingerprint) {
    methodName = 'fingerprint';
    continueIcon = Icons.fingerprint;
  } else if (isDeviceSupported) {
    methodName = 'device passcode';
    continueIcon = Icons.lock_outline;
  } else {
    methodName = 'device unlock';
    continueIcon = Icons.lock_outline;
  }

  final methodNameTitle = _titleCase(methodName);

  return BiometricSignInLabels(
    methodName: methodName,
    methodNameTitle: methodNameTitle,
    saveLoginCheckbox:
        'Save login on this device (use $methodName next time)',
    continueButton: 'Continue with $methodNameTitle',
    disableRow: 'Disable $methodName sign-in on this device',
    disableDialogTitle: 'Turn off $methodName sign in?',
    disableDialogBody:
        'You will need to enter your email and password the next time you sign in on this device.',
    disabledSnackbar: '$methodNameTitle sign in has been disabled on this device',
    continueIcon: continueIcon,
  );
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  if (value == 'Face ID or fingerprint') return 'Face ID or fingerprint';
  if (value == 'Face ID') return 'Face ID';
  return value[0].toUpperCase() + value.substring(1);
}
