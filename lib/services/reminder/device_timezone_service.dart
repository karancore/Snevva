import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceTimezoneService {
  DeviceTimezoneService._();

  static const MethodChannel _channel = MethodChannel(
    'com.coretegra.snevva/timezone',
  );

  static final DeviceTimezoneService instance = DeviceTimezoneService._();

  String? _cachedTimeZoneId;

  Future<String> getTimeZoneId({bool forceRefresh = false}) async {
    if (!forceRefresh && (_cachedTimeZoneId?.isNotEmpty ?? false)) {
      return _cachedTimeZoneId!;
    }

    try {
      final value = await _channel.invokeMethod<String>('getTimeZoneId');
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        _cachedTimeZoneId = normalized;
        return normalized;
      }
    } catch (_) {}

    final fallback = _fallbackTimeZoneId();
    _cachedTimeZoneId = fallback;
    return fallback;
  }

  Future<String?> getLastKnownTimezone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_known_timezone');
  }

  Future<int?> getLastKnownOffsetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_known_offset');
  }

  Future<void> saveLastKnownTimezone(String timezoneId, int offsetMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_timezone', timezoneId);
    await prefs.setInt('last_known_offset', offsetMinutes);
  }

  void prime(String timezoneId) {
    final normalized = timezoneId.trim();
    if (normalized.isEmpty) return;
    _cachedTimeZoneId = normalized;
  }

  String _fallbackTimeZoneId() {
    final runtimeName = DateTime.now().timeZoneName.trim();
    if (runtimeName.contains('/')) {
      return runtimeName;
    }
    return 'UTC';
  }
}
