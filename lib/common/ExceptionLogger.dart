import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/exception_Log.dart';
import 'package:snevva/services/api_service.dart';

class ExceptionLogger {
  static Future<void> log({
    required Object exception,
    StackTrace? stackTrace,
    String? userInput,
    String? methodName,
    String? className,
  }) async {
    try {
      final log = ExceptionLog(
        dataCode: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: await _getUserId(),
        userInput: userInput,
        errorMessage: exception.toString(),
        occuredAt: DateTime.now().toIso8601String(),
        stringException: exception.runtimeType.toString(),
        stackTrace: stackTrace?.toString(),
        innerException: null,
        methodName: methodName,
        className: className,
      );

      await ApiService.post(
        logexception,
        log.toJson(),
        withAuth: false,
        encryptionRequired: true,
      );

      print('✅ Exception logged to server');
    } catch (e) {
      print('❌ Failed to log exception: $e');
    }
  }

  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }
}
