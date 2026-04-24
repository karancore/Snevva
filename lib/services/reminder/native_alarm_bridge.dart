import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NativeAlarmEntry — a single alarm entry mirrored to the native (Kotlin) side.
//
// Dart writes these to SharedPreferences so [ReminderArmingHelper.kt] can
// re-arm AlarmManager entries without a live Flutter engine (e.g. on boot).
// ─────────────────────────────────────────────────────────────────────────────

class NativeAlarmEntry {
  final int alarmId;
  final int epochMs;
  final String groupId;
  final String category;
  final String title;
  final String body;
  final bool isPreAlarm;
  final int intervalMs; // 0 = one-shot

  const NativeAlarmEntry({
    required this.alarmId,
    required this.epochMs,
    required this.groupId,
    required this.category,
    required this.title,
    required this.body,
    required this.isPreAlarm,
    this.intervalMs = 0,
  });

  /// Builds a [NativeAlarmEntry] from a scheduled [AlarmSettings].
  /// Returns null if the payload is missing or unparseable.
  static NativeAlarmEntry? fromAlarmSettings(
    AlarmSettings alarm, {
    int intervalMs = 0,
  }) {
    final payload = alarm.payload;
    if (payload == null) return null;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return NativeAlarmEntry(
        alarmId: alarm.id,
        epochMs: alarm.dateTime.millisecondsSinceEpoch,
        groupId: (decoded['groupId'] ?? '').toString(),
        category: (decoded['category'] ?? '').toString().toLowerCase(),
        title: alarm.notificationSettings.title,
        body: alarm.notificationSettings.body,
        isPreAlarm: decoded['type'] == 'before',
        intervalMs: intervalMs,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'alarmId': alarmId,
    'epochMs': epochMs,
    'groupId': groupId,
    'category': category,
    'title': title,
    'body': body,
    'isPreAlarm': isPreAlarm,
    if (intervalMs > 0) 'intervalMs': intervalMs,
  };

  static NativeAlarmEntry? fromJson(Map<String, dynamic> json) {
    try {
      return NativeAlarmEntry(
        alarmId: (json['alarmId'] as num).toInt(),
        epochMs: (json['epochMs'] as num).toInt(),
        groupId: (json['groupId'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        isPreAlarm: (json['isPreAlarm'] ?? false) as bool,
        intervalMs: ((json['intervalMs'] ?? 0) as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NativeAlarmBridge — static API bridging Dart → Kotlin AlarmManager.
//
// ## How it works
//
// 1. After every Alarm.set() success, call armAlarm() or saveAndArm() so the
//    native Kotlin side also knows about the alarm.
//
// 2. The bridge writes the alarm list to SharedPreferences so BootReceiver.kt
//    can re-arm everything after a device reboot without opening the app.
//
// 3. MethodChannel calls are best-effort — they silently fail in WorkManager
//    background isolates. The SharedPrefs write always succeeds regardless.
// ─────────────────────────────────────────────────────────────────────────────

class NativeAlarmBridge {
  NativeAlarmBridge._();

  static const _channel = MethodChannel('com.coretegra.snevva/reminder_alarms');

  /// SharedPrefs key — must match PREFS_KEY in ReminderArmingHelper.kt.
  /// Kotlin reads this as "flutter.native_reminder_alarms" because the Dart
  /// shared_preferences plugin automatically prepends "flutter." to all keys.
  static const _prefsKey = 'native_reminder_alarms';

  // ───────────────────────────────────────────────────────────────
  // armAlarm — arm a single alarm immediately via MethodChannel
  // ───────────────────────────────────────────────────────────────

  /// Arms a native alarm. Call this after every successful Alarm.set().
  ///
  /// [alarmId]   — must match the id passed to Alarm.set()
  /// [epochMs]   — milliseconds since epoch when alarm fires
  /// [groupId]   — reminder group id (for rescheduling / cancellation)
  /// [category]  — 'water', 'meal', 'medicine', 'event', 'sleep', etc.
  /// [title]     — notification title
  /// [body]      — notification body
  /// [intervalMs]— optional repeat interval in ms (0 = one-shot)
  static Future<void> armAlarm({
    required int alarmId,
    required int epochMs,
    required String groupId,
    required String category,
    String title = 'Reminder',
    String body = '',
    int? intervalMs,
  }) async {
    try {
      await _channel.invokeMethod<bool>('armAlarm', {
        'alarmId': alarmId,
        'epochMs': epochMs,
        'groupId': groupId,
        'category': category,
        'title': title,
        'body': body,
        if (intervalMs != null && intervalMs > 0) 'intervalMs': intervalMs,
      });
      debugPrint(
        '[NativeAlarm] ✅ armAlarm id=$alarmId cat=$category'
        '${intervalMs != null ? ' interval=${intervalMs}ms' : ''}',
      );
    } catch (e) {
      debugPrint(
        '[NativeAlarm] ⚠️ armAlarm channel failed (ok in background): $e',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────
  // cancelAlarm — cancel a single alarm by id
  // ───────────────────────────────────────────────────────────────

  /// Cancels the native alarm for the given id. Call alongside Alarm.stop().
  static Future<void> cancelAlarm(int alarmId) async {
    try {
      await _channel.invokeMethod<bool>('cancelAlarm', {'alarmId': alarmId});
      debugPrint('[NativeAlarm] 🗑 cancelAlarm id=$alarmId');
    } catch (e) {
      debugPrint('[NativeAlarm] ⚠️ cancelAlarm channel failed: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // cancelAlarms — bulk cancel + remove from SharedPrefs
  // ───────────────────────────────────────────────────────────────

  /// Removes [alarmIds] from SharedPreferences and cancels them natively.
  /// Call when a reminder is deleted or rolled back.
  static Future<void> cancelAlarms(List<int> alarmIds) async {
    if (alarmIds.isEmpty) return;

    // Remove from SharedPrefs
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final existing = <int, NativeAlarmEntry>{};
        try {
          for (final item in jsonDecode(raw) as List) {
            final e = NativeAlarmEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            if (e != null) existing[e.alarmId] = e;
          }
        } catch (_) {}
        for (final id in alarmIds) {
          existing.remove(id);
        }
        await prefs.setString(
          _prefsKey,
          jsonEncode(existing.values.map((e) => e.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('[NativeAlarm] ⚠️ cancelAlarms prefs update failed: $e');
    }

    // Cancel on native side (best-effort)
    for (final id in alarmIds) {
      try {
        await _channel.invokeMethod<bool>('cancelAlarm', {'alarmId': id});
      } catch (_) {}
    }
    debugPrint('[NativeAlarm] 🗑 cancelAlarms ids=$alarmIds');
  }

  // ───────────────────────────────────────────────────────────────
  // saveAndArm — persist + arm a list of AlarmSettings (post-commit)
  // ───────────────────────────────────────────────────────────────

  /// Persists [alarms] to SharedPreferences and immediately signals Kotlin
  /// to arm them via AlarmManager.
  ///
  /// Call this after every ReminderAlarmTransaction commit.
  static Future<void> saveAndArm(
    List<AlarmSettings> alarms, {
    int intervalMs = 0,
  }) async {
    if (alarms.isEmpty) return;

    final entries =
        alarms
            .map(
              (a) =>
                  NativeAlarmEntry.fromAlarmSettings(a, intervalMs: intervalMs),
            )
            .whereType<NativeAlarmEntry>()
            .toList();

    if (entries.isEmpty) return;

    final scheduleJson = entries
        .map((entry) => entry.toJson())
        .toList(growable: false);

    // Step 1 — persist to SharedPrefs (always works, even in background isolates)
    try {
      await _mergeAndSave(entries);
    } catch (e) {
      debugPrint('[NativeAlarm] ⚠️ saveAndArm: prefs write failed: $e');
    }

    // Step 2 — signal Kotlin to arm immediately (best-effort, UI context only)
    try {
      await _channel.invokeMethod<bool>('armAll', {
        'json': jsonEncode(scheduleJson),
      });
      debugPrint(
        '[NativeAlarm] ✅ saveAndArm armAll triggered (${entries.length} alarms)',
      );
    } catch (_) {
      // Normal in WorkManager isolates — Kotlin will arm on next boot/app-open.
      debugPrint('[NativeAlarm] ⚠️ armAll skipped (background isolate)');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // saveSchedule — save raw JSON schedule list to SharedPrefs
  // ───────────────────────────────────────────────────────────────

  /// Saves the full alarm schedule (as a list of JSON maps) to SharedPrefs via
  /// the MethodChannel so BootReceiver can read it on next reboot.
  static Future<void> saveSchedule(List<Map<String, dynamic>> alarms) async {
    try {
      final json = jsonEncode(alarms);
      await _channel.invokeMethod<bool>('saveSchedule', {'json': json});
      debugPrint('[NativeAlarm] 💾 saveSchedule (${alarms.length} alarms)');
    } catch (e) {
      debugPrint('[NativeAlarm] ⚠️ saveSchedule failed: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // armAll — re-arm a raw list of alarm maps via MethodChannel
  // ───────────────────────────────────────────────────────────────

  static Future<void> armAll(List<Map<String, dynamic>> alarms) async {
    try {
      final json = jsonEncode(alarms);
      await _channel.invokeMethod<bool>('armAll', {'json': json});
      debugPrint('[NativeAlarm] ✅ armAll (${alarms.length} alarms)');
    } catch (e) {
      debugPrint('[NativeAlarm] ⚠️ armAll failed: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────
  // buildEntry — helper to build a raw schedule map
  // ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> buildEntry({
    required int alarmId,
    required DateTime dateTime,
    required String groupId,
    required String category,
    required String title,
    String body = '',
    int? intervalMs,
  }) {
    return {
      'alarmId': alarmId,
      'epochMs': dateTime.millisecondsSinceEpoch,
      'groupId': groupId,
      'category': category,
      'title': title,
      'body': body,
      if (intervalMs != null && intervalMs > 0) 'intervalMs': intervalMs,
    };
  }

  // ───────────────────────────────────────────────────────────────
  // Private helpers
  // ───────────────────────────────────────────────────────────────

  /// Merges [newEntries] into the existing SharedPrefs alarm list.
  /// New entries override old ones with the same alarmId (idempotent).
  /// Entries more than 5 minutes in the past are pruned automatically.
  static Future<void> _mergeAndSave(List<NativeAlarmEntry> newEntries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final existing = <int, NativeAlarmEntry>{};

    if (raw != null) {
      try {
        for (final item in jsonDecode(raw) as List) {
          final e = NativeAlarmEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (e != null) existing[e.alarmId] = e;
        }
      } catch (_) {}
    }

    // Merge: new entries win over old ones with the same alarmId
    for (final e in newEntries) {
      existing[e.alarmId] = e;
    }

    // Prune stale entries (more than 5 min in the past)
    final cutoff =
        DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch;
    existing.removeWhere((_, v) => v.epochMs < cutoff);

    await prefs.setString(
      _prefsKey,
      jsonEncode(existing.values.map((e) => e.toJson()).toList()),
    );
    debugPrint(
      '[NativeAlarm] 💾 Saved ${existing.length} alarms to SharedPrefs',
    );
  }
}
