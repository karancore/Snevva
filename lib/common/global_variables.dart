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

bool isProfileDisplayComplete(Map user) {
  if (!isProfileSetupInitialComplete(user)) return false;

  final bool emailValid = _hasNonEmptyString(user['Email']);
  final bool phoneValid = _hasNonEmptyString(user['PhoneNumber']);
  final bool addressValid = _hasNonEmptyString(user['AddressByUser']);

  return emailValid && phoneValid && addressValid;
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
  final normalized =
      DateTime(
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
    "JVBERi0xLjQKMSAwIG9iago8PC9UeXBlIC9DYXRhbG9nCi9QYWdlcyAyIDAgUgo+PgplbmRvYmoKMiAwIG9iago8PC9UeXBlIC9QYWdlcwovS2lkcyBbMyAwIFJdCi9Db3VudCAxCj4+CmVuZG9iagozIDAgb2JqCjw8L1R5cGUgL1BhZ2UKL1BhcmVudCAyIDAgUgovTWVkaWFCb3ggWzAgMCA1OTUgODQyXQovQ29udGVudHMgNSAwIFIKL1Jlc291cmNlcyA8PC9Qcm9jU2V0IFsvUERGIC9UZXh0XQovRm9udCA8PC9GMSA0IDAgUj4+Cj4+Cj4+CmVuZG9iago0IDAgb2JqCjw8L1R5cGUgL0ZvbnQKL1N1YnR5cGUgL1R5cGUxCi9OYW1lIC9GMQovQmFzZUZvbnQgL0hlbHZldGljYQovRW5jb2RpbmcgL01hY1JvbWFuRW5jb2RpbmcKPj4KZW5kb2JqCjUgMCBvYmoKPDwvTGVuZ3RoIDUzCj4+CnN0cmVhbQpCVAovRjEgMjAgVGYKMjIwIDQwMCBUZAooRHVtbXkgUERGKSBUagpFVAplbmRzdHJlYW0KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1MzUgZgowMDAwMDAwMDA5IDAwMDAwIG4KMDAwMDAwMDA2MyAwMDAwMCBuCjAwMDAwMDAxMjQgMDAwMDAgbgowMDAwMDAwMjc3IDAwMDAwIG4KMDAwMDAwMDM5MiAwMDAwMCBuCnRyYWlsZXIKPDwvU2l6ZSA2Ci9Sb290IDEgMCBSCj4+CnN0YXJ0eHJlZgo0OTUKJSVFT0YK";
