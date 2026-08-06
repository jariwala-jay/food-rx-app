import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_app/core/services/api_client.dart';
import 'package:http/http.dart' show ClientException;

/// Maps [local_auth] biometric failures/cancels into short copy for SnackBars.
String biometricAuthUserMessage(PlatformException error) {
  final code = error.code.toLowerCase();
  if (code == 'usercancelled' ||
      code == 'user_canceled' ||
      code == 'user_cancelled' ||
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'userfallback') {
    return 'Authentication cancelled';
  }
  if (code == 'lockedout' || code == 'permanentlylockedout') {
    return 'Too many attempts. Wait a moment and try again.';
  }
  if (code == 'notenrolled') {
    return 'No biometrics are set up on this device. Add Face ID or Touch ID in Settings.';
  }
  if (code == 'passcodenotset') {
    return 'Set a device passcode in Settings before using biometric sign-in.';
  }
  if (code == 'notavailable' || code == 'biometricnotavailable') {
    return 'Biometric authentication failed. Try again.';
  }
  if (code == 'auth_in_progress') {
    return 'Authentication already in progress. Please wait.';
  }
  return 'Something went wrong. Please try again.';
}

/// Maps thrown objects from HTTP/network and platform layers into short, non-technical copy.
/// Prefer this instead of interpolating [Object.toString] into SnackBars and [error] getters.
String userFacingErrorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is PlatformException) {
    final c = error.code.toLowerCase();
    if (c.contains('permission') ||
        c.contains('denied') ||
        c == 'photo_access_denied') {
      return 'Permission was denied. You can enable access in your device settings.';
    }
    if (c == 'usercancelled' ||
        c == 'user_canceled' ||
        c == 'user_cancelled' ||
        c == 'canceled' ||
        c == 'cancelled' ||
        c == 'userfallback' ||
        c == 'notavailable' ||
        c == 'biometricnotavailable' ||
        c == 'notenrolled' ||
        c == 'passcodenotset' ||
        c == 'lockedout' ||
        c == 'permanentlylockedout' ||
        c == 'auth_in_progress') {
      return biometricAuthUserMessage(error);
    }
    return 'Something went wrong. Please try again.';
  }
  if (error is StateError) {
    return 'This build is missing configuration. Please contact support.';
  }
  if (error is SocketException) {
    return 'Could not connect. Check your internet connection and try again.';
  }
  if (error is TimeoutException) {
    return 'The request timed out. Check your connection and try again.';
  }
  if (error is ClientException) {
    return 'Could not connect. Check your internet connection and try again.';
  }
  if (error is HandshakeException || error is TlsException) {
    return 'Secure connection failed. Check your connection and try again.';
  }
  final s = error.toString();
  if (s.contains('Failed host lookup') ||
      s.contains('No address associated with hostname') ||
      s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused')) {
    return 'Could not connect. Check your internet connection and try again.';
  }
  if (s.contains('MongoDB connection failed') ||
      s.contains('Database connection failed')) {
    return 'Could not connect to the server. Check your internet connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
