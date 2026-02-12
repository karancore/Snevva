import 'dart:convert';
import 'dart:io';

/// Minimal NDJSON logger for Cursor debug mode.
/// Writes to: d:\Git\Snevva\.cursor\debug.log
class AgentDebugLogger {
  static const String _logPath = r'd:\Git\Snevva\.cursor\debug.log';
  static const String _sessionId = 'debug-session';

  static void log({
    required String runId,
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, Object?> data = const {},
  }) {
    try {
      final payload = <String, Object?>{
        'sessionId': _sessionId,
        'runId': runId,
        'hypothesisId': hypothesisId,
        'location': location,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      File(_logPath).writeAsStringSync(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Never crash app due to debug logging.
    }
  }
}
