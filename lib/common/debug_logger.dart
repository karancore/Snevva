import 'dart:collection';
import 'package:flutter/foundation.dart';

class DebugLog {
  final String message;
  final String type; // INFO / API / ERROR
  final DateTime time;

  DebugLog(this.message, this.type) : time = DateTime.now();
}

class DebugLogger extends ChangeNotifier {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  final ListQueue<DebugLog> _logs = ListQueue();

  List<DebugLog> get logs => _logs.toList().reversed.toList();

  void log(String message, {String type = "INFO"}) {
    if (!kDebugMode) return; // Only in debug builds

    if (_logs.length > 500) {
      _logs.removeFirst(); // prevent memory leak
    }

    _logs.add(DebugLog(message, type));
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
