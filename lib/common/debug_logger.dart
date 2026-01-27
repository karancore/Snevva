import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugLog {
  final String message;
  final String type; // INFO / API / ERROR
  final DateTime time;

  DebugLog(this.message, this.type, this.time);

  Map<String, dynamic> toJson() => {
        'message': message,
        'type': type,
        'time': time.toIso8601String(),
      };

  factory DebugLog.fromJson(Map<String, dynamic> json) {
    return DebugLog(
      json['message'],
      json['type'],
      DateTime.parse(json['time']),
    );
  }
}

class DebugLogger extends ChangeNotifier {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal() {
    _load(); // restore logs on startup
  }

  static const _storageKey = 'debug_logs';

  final ListQueue<DebugLog> _logs = ListQueue();

  List<DebugLog> get logs => _logs.toList().reversed.toList();

  void log(String message, {String type = "INFO"}) {
    if (!kDebugMode) return;

    if (_logs.length >= 500) {
      _logs.removeFirst();
    }

    _logs.add(DebugLog(message, type, DateTime.now()));
    _save();
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _logs.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null) {
      final List decoded = jsonDecode(raw);
      _logs.clear();
      for (final item in decoded) {
        _logs.add(DebugLog.fromJson(item));
      }
      notifyListeners();
    }
  }
}
