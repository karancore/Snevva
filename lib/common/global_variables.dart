import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:intl/intl.dart';

import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../consts/consts.dart';

enum Option { times, interval }

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

List<String> generateMonthLabels(DateTime month) {
  final total = daysInMonth(month.year, month.month);
  return List.generate(total, (i) => '${i + 1}');
}

int alarmsId() {
  return DateTime.now().millisecondsSinceEpoch % 2147483647;
}

DateTime combineWithToday(TimeOfDay time) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, time.hour, time.minute);
}

DateTime toDateTimeToday(TimeOfDay time) {
  final now = DateTime.now();
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
      print('Error formatting time: $e');
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
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    return DateFormat('hh:mm a').format(dateTime);
  } catch (e) {
    return '$hour:$minute';
  }
}

TimeOfDay parseTime(String timeString) {
  final format = DateFormat("hh:mm a");
  return TimeOfDay.fromDateTime(format.parse(timeString));
}

String pluralizeHour(int value) => value > 1 ? 'hours' : 'hour';

void logLong(String tag, String text) {
  const chunkSize = 800;
  for (var i = 0; i < text.length; i += chunkSize) {
    debugPrint(
      '$tag ${text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize)}',
    );
  }
}
