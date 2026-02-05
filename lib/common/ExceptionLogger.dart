import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/exception_Log.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/auth_service.dart';

class ExceptionLogger {
  static Future<void> log({
    required Object exception,
    StackTrace? stackTrace,
    String? userInput,
    String? methodName,
    String? className,
  }) async {
    try {
      final extracted = stackTrace != null
          ? _extractFromStack(stackTrace)
          : {};

      print("Logging exception: ${exception.toString()}");
      print("extracted methodName: ${extracted['methodName']}, className: ${extracted['className']}");

      final log = ExceptionLog(
        dataCode: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: await _getUserId(),
        userInput: userInput,
        errorMessage: exception.toString(),
        occuredAt: DateTime.now().toIso8601String(),
        stringException: exception.runtimeType.toString(),
        stackTrace: stackTrace?.toString(),
        innerException: null,
        methodName: methodName ?? extracted['methodName'],
        className: className ?? extracted['className'],
      );

      AuthService.logExceptionToServer(log.toJson());
    } catch (_) {}
  }

  static Map<String, String?> _extractFromStack(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');

    // Skip framework lines
    final line = lines.firstWhere(
      (l) =>
          !l.contains('ExceptionLogger') &&
          !l.contains('runZonedGuarded') &&
          !l.contains('ErrorWidget'),
      orElse: () => '',
    );

    // #0   AuthService.login (package:app/services/auth_service.dart:42:10)
    final methodMatch = RegExp(r'#\d+\s+(.+?)\s+\(').firstMatch(line);
    final fileMatch = RegExp(r'\((.+?):\d+:\d+\)').firstMatch(line);

    return {
      'methodName': methodMatch?.group(1),
      'className': fileMatch?.group(1),
    };
  }

  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('PatientCode');
  }
}
