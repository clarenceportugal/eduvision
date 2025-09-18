import 'package:flutter/foundation.dart';

class Logger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      // Debug: 
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      // Debug: 
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      // Debug: 
    }
  }
}
