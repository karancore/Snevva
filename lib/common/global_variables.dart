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
  if (!occupationValid) {
    occupationValid = _hasNonEmptyString(user['Occupation']);
  }

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

int generateWaterAlarmId(int reminderId, int index) {
  return reminderId * 10 + index;
}

DateTime combineWithToday(TimeOfDay time) {
  return DateTime(now.year, now.month, now.day, time.hour, time.minute);
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

String formatReminderTime(List remindTimes) {
  if (remindTimes.isEmpty) return 'N/A';

  List<String> formattedTimes = [];
  for (var time in remindTimes) {
    try {
      if (time is String) {
        try {
          DateTime dateTime = DateTime.parse(time);
          formattedTimes.add(DateFormat('hh:mm a').format(dateTime));
        } catch (e) {
          formattedTimes.add(time);
        }
      } else if (time is DateTime) {
        formattedTimes.add(DateFormat('hh:mm a').format(time));
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      formattedTimes.add(time.toString());
    }
  }

  return formattedTimes.join(', ');
}

String formatDate(int? day, int? month, int? year) {
  if (day == null || month == null || year == null) return 'N/A';
  return '$day/$month/$year';
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
