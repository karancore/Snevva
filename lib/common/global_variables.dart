import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../consts/consts.dart';

//Interval - hours
enum Option { times, interval }

enum ReminderCategory { medicine, water, meal, event }

double asDouble(num? value) {
  if (value == null) return 1.0;
  return value.toDouble();
}

const String reminderBox = 'reminders_box';

//to access medicne do (reminderBox)[medicineKey];

// Changed from a fixed final DateTime to a getter so `now` always returns
// the current time when used. This prevents stale-date bugs across isolates.
DateTime get now => DateTime.now();

bool startsWithCapital(String value) {
  if (value.isEmpty) return false;
  return value[0] == value[0].toUpperCase();
}

class ParsedTime {
  final int hour;
  final int minute;

  ParsedTime(this.hour, this.minute);
}

/// "23:59" -> 23 , 59
ParsedTime parse24Hour(String time) {
  final parts = time.split(':');
  return ParsedTime(int.parse(parts[0]), int.parse(parts[1]));
}

int generateNotificationId(String dataCode, String time) {
  return (dataCode + time).hashCode.abs();
}

class MaxValueTextInputFormatter extends TextInputFormatter {
  final int max;

  MaxValueTextInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    int value = int.tryParse(newValue.text) ?? 0;
    if (value > max) {
      return oldValue; // reject new input if greater than max
    }
    return newValue;
  }
}

String getGender() {
  String localGender = 'Not Specified';
  final signInController = Get.find<SignInController>();
  final userInfo = signInController.userProfData ?? {};
  final userData = userInfo['data'];
  final gender =
      (userData != null && userData['Gender'] != null)
          ? userData['Gender']
          : localGender ?? 'Not Specified';
  return gender['Gender'] as String;
}

TimeOfDay parseTimeOfDay(String timeString) {
  final format = DateFormat("hh:mm a"); // for 12-hour format with AM/PM
  final dateTime = format.parse(timeString);
  return TimeOfDay.fromDateTime(dateTime);
}

String fmtDuration(Duration d) =>
    "${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, "0")}m";

String formatDurationHHmm(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  final hoursStr = hours.toString().padLeft(2, '0');
  final minutesStr = minutes.toString().padLeft(2, '0');

  return "$hoursStr:$minutesStr";
}

Duration parseDuration(String d) {
  final hourPart = d.split("h")[0].trim();
  final minutePart = d.split("h")[1].replaceAll("m", "").trim();

  final hours = int.parse(hourPart);
  final minutes = int.parse(minutePart);

  return Duration(hours: hours, minutes: minutes);
}

double hp(BuildContext context, double percent) =>
    MediaQuery.of(context).size.height * percent;

double wp(BuildContext context, double percent) =>
    MediaQuery.of(context).size.width * percent;

bool hasEmptyValue(dynamic value) {
  if (value == null) return true;

  if (value is String) return value.trim().isEmpty;

  if (value is num) return value == 0;

  if (value is List) {
    return value.any((v) => hasEmptyValue(v));
  }

  if (value is Map) {
    return value.values.any((v) => hasEmptyValue(v));
  }

  return false;
}

bool isProfileSetupInitialComplete(Map user) {
  if (user.isEmpty) return false;

  final bool nameValid = _hasNonEmptyString(user['Name']);
  final bool genderValid = _hasNonEmptyString(user['Gender']);

  final int? day = _asPositiveInt(user['DayOfBirth']);
  final int? month = _asPositiveInt(user['MonthOfBirth']);
  final int? year = _asPositiveInt(user['YearOfBirth']);
  final bool dobValid = day != null && month != null && year != null;

  bool occupationValid = false;
  final occupationData = user['OccupationData'];
  if (occupationData is Map) {
    occupationValid = _hasNonEmptyString(occupationData['Name']);
  }
  // if (!occupationValid) {
  //   occupationValid = _hasNonEmptyString(user['Occupation']);
  // }

  return nameValid && genderValid && dobValid && occupationValid;
}

bool _hasNonEmptyString(dynamic value) {
  if (value is String) return value.trim().isNotEmpty;
  return false;
}

int? _asPositiveInt(dynamic value) {
  if (value is int && value > 0) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

String formatDurationToHM(Duration d) {
  final int hours = d.inHours;
  final int minutes = d.inMinutes % 60;

  if (minutes == 0) {
    return "${hours}h";
  }

  return "${hours}h ${minutes}m";
}

Duration calculateFixedDeepSleep(DateTime bed, DateTime wake) {
  if (wake.isBefore(bed)) {
    wake = wake.add(Duration(days: 1));
  }
  return wake.difference(bed);
}

int daysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

String _dateKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

int getCurrentDateIndex() {
  final index = DateTime.now().day - 1;

  return index;
}

List<String> generateMonthLabels(DateTime month) {
  final int totalDays =
      (month.year == now.year && month.month == now.month)
          ? now
              .day // 🔥 only till today
          : daysInMonth(month.year, month.month); // full month for past months

  return List.generate(totalDays, (i) => '${i + 1}');
}

int alarmsId() {
  return DateTime.now().millisecondsSinceEpoch % 2147483647;
}

// The `alarm` plugin validates ids against 32-bit signed int max.
// Keep IDs <= 2147483647 and (when possible) deterministic across restarts.
const int _kAlarmIdIntMax = 2147483647;
const int _kLegacyAlarmIdMaxGroup = 21474; // 21474*100000+2359 <= 2147483647

int _fnv1a32(String input) {
  var hash = 0x811C9DC5; // 2166136261
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // 16777619
  }
  return hash;
}

int buildAlarmId({required int groupId, required DateTime time, String? salt}) {
  final normalizedSalt = (salt ?? '').trim();

  // Backward-compatible deterministic IDs for older schedules (only when safe).
  if (normalizedSalt.isEmpty &&
      groupId >= 0 &&
      groupId <= _kLegacyAlarmIdMaxGroup) {
    return groupId * 100000 + time.hour * 100 + time.minute;
  }

  final seed = '$normalizedSalt|$groupId|${time.toIso8601String()}';
  final hashed = _fnv1a32(seed) & _kAlarmIdIntMax; // 0..2147483647
  return hashed == 0 ? 1 : hashed;
}

int computeAlarmId({
  required int reminderId,
  required int scheduleVersion,
  required DateTime fireTime,
  required bool isPreAlarm,
}) {
  final normalized = DateTime(
    fireTime.year,
    fireTime.month,
    fireTime.day,
    fireTime.hour,
    fireTime.minute,
    fireTime.second,
  ).toIso8601String();

  final seed = '$reminderId|$scheduleVersion|$normalized|$isPreAlarm';

  final hash64 = _fnv1a64(seed.codeUnits);

  final id = (hash64 ^ (hash64 >> 32)) & 0x7fffffff;

  return id == 0 ? 1 : id;
}

int _fnv1a64(List<int> bytes) {
  const int fnvPrime = 0x100000001b3;
  const int offsetBasis = 0xcbf29ce484222325;
  const int mask64 = 0xFFFFFFFFFFFFFFFF;
  int hash = offsetBasis;
  for (var byte in bytes) {
    hash ^= byte;
    hash = (hash * fnvPrime) & mask64;
  }

  return hash;
}

int generateWaterAlarmId(int reminderId, int index) {
  return reminderId * 10 + index;
}

DateTime combineWithToday(TimeOfDay time) {
  return DateTime(now.year, now.month, now.day, time.hour, time.minute);
}

List<int> sanitizeIds(List<dynamic>? input) {
  return (input ?? []).whereType<int>().toSet().toList();
}

final Map<String, bool> _txnLocks = {};

Future<void> runWithLock(String key, Future<void> Function() fn) async {
  if (_txnLocks[key] == true) return;

  _txnLocks[key] = true;
  try {
    await fn();
  } finally {
    _txnLocks[key] = false;
  }
}

void logTxn(Map<String, dynamic> data) {
  debugPrint(
    '[ReminderTxn] ' + data.entries.map((e) => '${e.key}=${e.value}').join(' '),
  );
}

DateTime toDateTimeToday(TimeOfDay time) {
  return DateTime(now.year, now.month, now.day, time.hour, time.minute);
}

DateTimeRange buildTimeWindow(TimeOfDay start, TimeOfDay end) {
  final startDT = toDateTimeToday(start);
  var endDT = toDateTimeToday(end);

  // Handles overnight range (e.g. 10 PM → 6 AM)
  if (endDT.isBefore(startDT)) {
    endDT = endDT.add(const Duration(days: 1));
  }

  return DateTimeRange(start: startDT, end: endDT);
}

TimeOfDay stringToTimeOfDay(String time) {
  final format = DateFormat('hh:mm a'); // 09:30 AM
  final dateTime = format.parse(time);
  return TimeOfDay.fromDateTime(dateTime);
}

String formatReminderTime(List<String> remindTimes) {
  if (remindTimes.isEmpty) return 'N/A';

  List<String> formattedTimes = [];

  for (var time in remindTimes) {
    try {
      DateTime? dateTime;

      if (time is String) {
        try {
          dateTime = DateTime.parse(time);

          // 🔥 Always normalize to local time
          dateTime = dateTime.toLocal();
        } catch (_) {
          // Not ISO → assume already formatted (e.g. "09:30 AM")
          formattedTimes.add(time);
          continue;
        }
      } else if (time is DateTime) {
        dateTime = DateTime.parse(time).toLocal();
      }

      if (dateTime != null) {
        formattedTimes.add(DateFormat('hh:mm a').format(dateTime));
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      formattedTimes.add(time.toString());
    }
  }

  return formattedTimes.join(', ');
}
String formatDate(String dateStr) {
  DateTime parsedDate = DateTime.parse(dateStr); // "2026-04-18"
  String formattedDate = DateFormat('MMMM dd, yyyy').format(parsedDate);
  return formattedDate;
}

double getListHeight(int itemCount, double itemHeight, double maxHeight) {
  return (itemCount * itemHeight).clamp(0, maxHeight);
}

String formatTimeFromHourMinute(int hour, int minute) {
  try {
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat('hh:mm a').format(dateTime);
  } catch (e) {
    return '$hour:$minute';
  }
}

double heightFactor = 1.073;
double widthFactor = 1.047;

// final actualHeight = MediaQuery.of(context).size.height;
// final actualWidth = MediaQuery.of(context).size.width;
//
// // Design reference
// const designHeight = 852.0;
// const designWidth = 393.0;
//
// // Widget design size
// const widgetHeight = 180.0;
// const widgetWidth = 280.0;
//
// // Scale factors
// final heightScale = actualHeight / designHeight;
// final widthScale = actualWidth / designWidth;
//
// // Scaled widget size
// final scaledHeight = widgetHeight * heightScale;
// final scaledWidth = widgetWidth * widthScale;
// Height multiplier: 1.073
//
// Width multiplier: 1.047

TimeOfDay parseTime(String timeString) {
  final format = DateFormat("hh:mm a");
  return TimeOfDay.fromDateTime(format.parse(timeString));
}

String encryptPasswordRuntime(String password) {
  final bytes = utf8.encode(password);
  final digest = md5.convert(bytes);
  return digest.toString();
}

TimeOfDay parseTimeNew(String input) {
  // Normalize: ensure space before AM/PM
  final normalized = input
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAllMapped(
        RegExp(r'(AM|PM)$', caseSensitive: false),
        (m) => ' ${m.group(0)}',
      );

  final date = DateFormat('hh:mm a').parse(normalized);

  return TimeOfDay(hour: date.hour, minute: date.minute);
}

String pluralizeHour(int value) => value > 1 ? 'hours' : 'hour';

void logLong(String tag, String text) {
  const chunkSize = 2000;
  for (var i = 0; i < text.length; i += chunkSize) {
    debugPrint(
      '$tag ${text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize)}',
    );
  }
}

int medicineAlarmId(String title, String medicineName, TimeOfDay time) {
  return '$title-$medicineName-${time.hour}-${time.minute}'.hashCode;
}

DateTime buildDateTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// String buildMedicineText(dynamic medicineList) {
//   if (medicineList == null || medicineList is! List) return '';
//
//   return medicineList
//       .map((e) {
//         if (e is MedicineItem) return e.name;
//         if (e is String) return e;
//         if (e is Map && e['name'] != null) return e['name'];
//         return '';
//       })
//       .where((e) => e.isNotEmpty)
//       .join(', ');
// }

Map<String, dynamic> deepNormalizeMap(Map raw) {
  return raw.map((key, value) {
    if (value is Map) {
      return MapEntry(key.toString(), deepNormalizeMap(value));
    } else if (value is List) {
      return MapEntry(
        key.toString(),
        value.map((e) {
          if (e is Map) return deepNormalizeMap(e);
          return e;
        }).toList(),
      );
    }
    return MapEntry(key.toString(), value);
  });
}

List<List<FlSpot>> splitByZero(List<FlSpot> points) {
  final List<List<FlSpot>> segments = [];
  List<FlSpot> currentSegment = [];

  for (final point in points) {
    if (point.y <= 0) {
      if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
        currentSegment = [];
      }
    } else {
      currentSegment.add(point);
    }
  }

  if (currentSegment.isNotEmpty) {
    segments.add(currentSegment);
  }

  return segments;
}

DateTime buildDateTimeFromTimeString({required String time, String? date}) {
  final trimmedTime = time.trim();
  if (trimmedTime.isEmpty) {
    throw const FormatException('Time string is empty');
  }

  // 1) Full datetime (ISO or Dart's DateTime.toString() formats).
  final parsedDirect = DateTime.tryParse(trimmedTime);
  if (parsedDirect != null) {
    return parsedDirect.isUtc ? parsedDirect.toLocal() : parsedDirect;
  }

  // 2) Time-only (12h with AM/PM or 24h).
  final timeMatch = RegExp(
    r'^\s*(\d{1,2})\s*:\s*(\d{1,2})(?:\s*:\s*(\d{1,2}))?\s*([AaPp][Mm])?\s*$',
  ).firstMatch(trimmedTime);
  if (timeMatch == null) {
    throw FormatException('Unsupported time format: "$time"');
  }

  final rawHour = int.parse(timeMatch.group(1)!);
  final rawMinute = int.parse(timeMatch.group(2)!);

  if (rawMinute < 0 || rawMinute > 59) {
    throw FormatException('Invalid minute in time: "$time"');
  }

  final meridiem = timeMatch.group(4);
  int hours;
  if (meridiem != null) {
    if (rawHour < 1 || rawHour > 12) {
      throw FormatException('Invalid hour in 12-hour time: "$time"');
    }
    final isPm = meridiem.toUpperCase() == 'PM';
    if (rawHour == 12) {
      hours = isPm ? 12 : 0;
    } else {
      hours = isPm ? rawHour + 12 : rawHour;
    }
  } else {
    if (rawHour < 0 || rawHour > 23) {
      throw FormatException('Invalid hour in 24-hour time: "$time"');
    }
    hours = rawHour;
  }

  final minutes = rawMinute;

  DateTime scheduled;
  final dateHint = (date ?? '').trim();
  if (dateHint.isNotEmpty) {
    final parsedDate = DateTime.tryParse(dateHint);
    final localDate =
        parsedDate != null
            ? (parsedDate.isUtc ? parsedDate.toLocal() : parsedDate)
            : null;

    if (localDate != null) {
      scheduled = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
        hours,
        minutes,
      );
      return scheduled;
    }

    final dateParts = dateHint.split('-');
    if (dateParts.length != 3) {
      throw FormatException('Unsupported date format: "$date"');
    }
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    scheduled = DateTime(year, month, day, hours, minutes);
  } else {
    final now = DateTime.now();
    scheduled = DateTime(now.year, now.month, now.day, hours, minutes);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
  }
  return scheduled;
}

const excelDummy =
    "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";

const pdfDummy =
    "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";
