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

  // Maps common OS-reported timezone abbreviations to IANA timezone IDs.
  // Android often returns abbreviations like 'IST' instead of 'Asia/Kolkata',
  // causing a spurious UTC fallback that shifts scheduled times by the full
  // UTC offset (e.g. +5:30 for IST users).
  static const _abbreviationToIana = <String, String>{
    'IST': 'Asia/Kolkata',
    'GMT': 'Europe/London',
    'BST': 'Europe/London',
    'CET': 'Europe/Paris',
    'CEST': 'Europe/Paris',
    'EET': 'Europe/Athens',
    'EEST': 'Europe/Athens',
    'MSK': 'Europe/Moscow',
    'EST': 'America/New_York',
    'EDT': 'America/New_York',
    'CST': 'America/Chicago',
    'CDT': 'America/Chicago',
    'MST': 'America/Denver',
    'MDT': 'America/Denver',
    'PST': 'America/Los_Angeles',
    'PDT': 'America/Los_Angeles',
    'AKST': 'America/Anchorage',
    'AKDT': 'America/Anchorage',
    'HST': 'Pacific/Honolulu',
    'JST': 'Asia/Tokyo',
    'KST': 'Asia/Seoul',
    'CST_CHINA': 'Asia/Shanghai',
    'HKT': 'Asia/Hong_Kong',
    'SGT': 'Asia/Singapore',
    'ICT': 'Asia/Bangkok',
    'PKT': 'Asia/Karachi',
    'NPT': 'Asia/Kathmandu',
    'BST_BD': 'Asia/Dhaka',
    'MMT': 'Asia/Rangoon',
    'WIB': 'Asia/Jakarta',
    'AEST': 'Australia/Sydney',
    'AEDT': 'Australia/Sydney',
    'ACST': 'Australia/Darwin',
    'ACDT': 'Australia/Adelaide',
    'AWST': 'Australia/Perth',
    'NZST': 'Pacific/Auckland',
    'NZDT': 'Pacific/Auckland',
    'WAT': 'Africa/Lagos',
    'CAT': 'Africa/Harare',
    'EAT': 'Africa/Nairobi',
    'SAST': 'Africa/Johannesburg',
    'ART': 'America/Argentina/Buenos_Aires',
    'BRT': 'America/Sao_Paulo',
    'BRST': 'America/Sao_Paulo',
    'COT': 'America/Bogota',
    'PET': 'America/Lima',
  };

  String _fallbackTimeZoneId() {
    final runtimeName = DateTime.now().timeZoneName.trim();

    // Already in IANA format (e.g. 'America/New_York')
    if (runtimeName.contains('/')) return runtimeName;

    // Known abbreviation → IANA ID
    final mapped = _abbreviationToIana[runtimeName];
    if (mapped != null) return mapped;

    // Last-resort: don't cache a wrong 'UTC' — return UTC only if offset is 0
    final offset = DateTime.now().timeZoneOffset;
    if (offset == Duration.zero) return 'UTC';

    // Unknown non-UTC zone: log and return UTC so callers can handle it
    debugPrint(
      '⚠️ DeviceTimezoneService: unknown timezone abbreviation "$runtimeName" '
      '(offset ${offset.inMinutes} min). Falling back to UTC — '
      'notifications may fire at wrong local time.',
    );
    return 'UTC';
  }
}
