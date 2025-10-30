import 'package:flutter/foundation.dart';

class AppLogger {
  static bool enabled = true;

  static void d(Object? message) {
    if (!enabled) return;
    debugPrint(message?.toString());
  }
}
