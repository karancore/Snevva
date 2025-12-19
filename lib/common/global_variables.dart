import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:intl/intl.dart';

import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../consts/consts.dart';

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

const String dietPlaceholder =
    "https://community.softr.io/uploads/db9110/original/2X/7/74e6e7e382d0ff5d7773ca9a87e6f6f8817a68a6.jpeg";
