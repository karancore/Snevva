import 'package:flutter/foundation.dart';
import 'package:snevva/env/env.dart';

class ConsoleService {
  ConsoleService._();

  static void log(Object? message, [Object? message2]) {
    if (Env.enableConsole) {
      debugPrint(_format(message, message2));
    }
  }

  static void warn(Object? message, [Object? message2]) {
    if (Env.enableConsole) {
      debugPrint('⚠️ ${_format(message, message2)}');
    }
  }

  static void error(Object? message, [Object? message2]) {
    if (Env.enableConsole) {
      debugPrint('❌ ${_format(message, message2)}');
    }
  }

  static String _format(Object? m1, Object? m2) {
    if (m2 == null) return m1.toString();
    return '$m1 $m2';
  }
}
