import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/consts/consts.dart';

class DeviceTimezoneService {
  DeviceTimezoneService._();

  static const MethodChannel _channel =
  MethodChannel('com.coretegra.snevva/timezone');

  static final DeviceTimezoneService instance =
  DeviceTimezoneService._();

  String? _cachedTimeZoneId;

  // -------------------------------------------------
  // MAIN METHOD (FIXED)
  // -------------------------------------------------
  Future<String> getTimeZoneId({bool forceRefresh = false}) async {
    if (!forceRefresh && (_cachedTimeZoneId?.isNotEmpty ?? false)) {
      return _cachedTimeZoneId!;
    }

    try {
      final value = await _channel.invokeMethod<String>('getTimeZoneId');
      final normalized = (value ?? '').trim();

      if (normalized.isNotEmpty) {
        final mapped = _mapToIana(normalized);

        // ❌ DO NOT cache UTC (important)
        if (mapped != "UTC") {
          _cachedTimeZoneId = mapped;
        }

        debugPrint("🌍 Native TZ: $normalized → $mapped");

        return mapped;
      }
    } catch (e) {
      debugPrint("❌ TZ MethodChannel error: $e");
    }

    final fallback = _fallbackTimeZoneId();

    // ❌ DO NOT cache UTC fallback
    if (fallback != "UTC") {
      _cachedTimeZoneId = fallback;
    }

    debugPrint("⚠️ Using fallback TZ: $fallback");

    return fallback;
  }

  // -------------------------------------------------
  // MAP ABBREVIATION → IANA (FIXED)
  // -------------------------------------------------
  String _mapToIana(String tz) {
    if (tz.contains('/')) return tz;

    return _abbreviationToIana[tz] ??
        (tz == "IST" ? "Asia/Kolkata" : tz);
  }

  // -------------------------------------------------
  // SAFE FALLBACK (FIXED)
  // -------------------------------------------------
  String _fallbackTimeZoneId() {
    final runtimeName = DateTime
        .now()
        .timeZoneName
        .trim();

    // Already correct format
    if (runtimeName.contains('/')) return runtimeName;

    // Try mapping
    final mapped = _abbreviationToIana[runtimeName];
    if (mapped != null) return mapped;

    final offset = DateTime
        .now()
        .timeZoneOffset;

    // ✅ INDIA FIX
    if (offset.inMinutes == 330) {
      return "Asia/Kolkata";
    }

    // Only real UTC allowed
    if (offset == Duration.zero) return 'UTC';

    debugPrint(
      '⚠️ Unknown TZ "$runtimeName" (offset ${offset
          .inMinutes}) → forcing Asia/Kolkata',
    );

    return "Asia/Kolkata";
  }

  // -------------------------------------------------
  // OPTIONAL STORAGE (UNCHANGED)
  // -------------------------------------------------
  Future<void> saveLastKnownTimezone(String timezoneId,
      int offsetMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_timezone', timezoneId);
    await prefs.setInt('last_known_offset', offsetMinutes);
  }

  Future<String?> getLastKnownTimezone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_known_timezone');
  }

  Future<int?> getLastKnownOffsetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_known_offset');
  }

  void prime(String timezoneId) {
    final normalized = timezoneId.trim();
    if (normalized.isEmpty) return;
    _cachedTimeZoneId = normalized;
  }

  // -------------------------------------------------
  // ABBREVIATION MAP (UNCHANGED)
  // -------------------------------------------------
  static const _abbreviationToIana = <String, String>{
    'IST': 'Asia/Kolkata',
    'PKT': 'Asia/Karachi',
    'NPT': 'Asia/Kathmandu',
    'BST': 'Europe/London',
    'GMT': 'Europe/London',
    'CET': 'Europe/Paris',
    'EET': 'Europe/Athens',
    'MSK': 'Europe/Moscow',
    'EST': 'America/New_York',
    'PST': 'America/Los_Angeles',
    'JST': 'Asia/Tokyo',
    'KST': 'Asia/Seoul',
  };
}